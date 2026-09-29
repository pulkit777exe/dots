pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Polkit

/*
  Auth service.

  Wraps Quickshell's native PolkitAgent (in-process D-Bus polkit agent;
  see https://quickshell.org/docs/v0.3.0/types/Quickshell.Services.Polkit/PolkitAgent).
  Declaring a PolkitAgent anywhere in the QML tree automatically registers
  it as the active org.freedesktop.PolicyKit1.AuthenticationAgent on the
  session bus. No Process/SetuidHelper or Python helper is needed.

  The rest of the shell should continue to use the same API the old
  Python helper exposed:

      Auth.pending  // null | { cookie, actionId, message, iconName,
                    //         identities, selectedIdentity, errorText,
                    //         responseVisible, inputPrompt }
      Auth.respond(password)
      Auth.cancel()
      Auth.requestBegan / Auth.requestEnded
      Auth.available

  `pending` is a *bound* property that derives directly from
  `agent.flow` and all of its relevant sub-properties, so in-flow
  updates (retry errors, new PAM prompts, responseVisible toggles)
  automatically invalidate the binding and refresh the dialog —
  no manual Connections to supplementaryMessage / isResponseRequired
  needed.

  Signals `requestBegan` / `requestEnded` are emitted from
  `onPendingChanged` so that outer surfaces (e.g. focus grabs)
  can react without polling.

  NOTE: only ONE PolkitAgent may be registered per session bus.
  Do not declare another PolkitAgent elsewhere in the config.
*/

Singleton {
    id: root

    // `available` mirrors isRegistered so shell.qml can show
    // a degraded state if registration failed.
    property bool available: agent.isRegistered

    // Bound derivation from the active AuthFlow.
    // All flow properties referenced here become binding dependencies,
    // so any change (message, supplementaryMessage, inputPrompt, etc.)
    // automatically rebuilds `pending` and refreshes AuthDialog.
    property var pending: {
        const f = agent.flow;
        if (!f) return null;

        // Reference every flow property that should invalidate the
        // binding when it changes. The value for cookie/actionId/etc.
        // is read directly; the dummy reads below ensure the binding
        // also subscribes to the *change signals* for fields we only
        // surface conditionally (e.g. supplementaryMessage).
        // QML's binding tracker records any property read that occurs
        // during evaluation, so reading them here is sufficient.
        const touch = [
            f.supplementaryMessage,
            f.supplementaryIsError,
            f.inputPrompt,
            f.responseVisible,
            f.isResponseRequired,
            f.identities,
            f.selectedIdentity,
            f.failed,
            f.isCompleted,
            f.isSuccessful,
            f.isCancelled
        ];

        // Build the stable shape the dialog expects.
        return {
            cookie: f.cookie,
            actionId: f.actionId,
            message: f.message,
            iconName: f.iconName,
            identities: f.identities,
            selectedIdentity: f.selectedIdentity,
            responseVisible: f.responseVisible,
            isResponseRequired: f.isResponseRequired,
            inputPrompt: f.inputPrompt,
            failed: f.failed,
            // Surface supplementaryMessage only when it's an error;
            // info-level supplementary messages are ignored for now
            // (they could be surfaced as a hint if desired).
            errorText: f.supplementaryIsError ? f.supplementaryMessage : "",
            // Keep raw message too if you want to show non-error hints:
            supplementaryMessage: f.supplementaryMessage,
            supplementaryIsError: f.supplementaryIsError
        };
    }

    // Internal bookkeeping so we can emit requestBegan/Ended exactly
    // once per authentication turn.
    property var prevPending: null

    onPendingChanged: {
        const prev = root.prevPending;
        const next = root.pending;

        // null -> object : new request began
        if (!prev && next) {
            root.requestBegan(next);
        }
        // object -> null : request finished (success / cancel / daemon drop)
        // The success flag is lost once flow is null, so we currently
        // surface `false` generically; callers only need to know the
        // prompt should hide, not the exact outcome. If you need the
        // precise result, inspect `flow.isSuccessful` via a Connections
        // to `agent.flow` before it clears.
        else if (prev && !next) {
            root.requestEnded(false);
        }
        // object -> object with different cookie : new request chained
        // immediately after the previous one (queued requests path)
        else if (prev && next && prev.cookie !== next.cookie) {
            root.requestEnded(false);
            root.requestBegan(next);
        }

        root.prevPending = next;
    }

    signal requestBegan(var request)
    signal requestEnded(bool success)

    PolkitAgent {
        id: agent

        // Default is /org/quickshell/PolkitAgent; explicit path kept
        // to document intent and avoid colliding with the old Python
        // helper if it's still installed alongside.
        path: "/org/quickshell/PolkitAgent"
    }

    function respond(password) {
        if (!agent.flow) return;
        agent.flow.submit(password);
    }

    function cancel() {
        if (!agent.flow) return;
        agent.flow.cancelAuthenticationRequest();
    }
}
