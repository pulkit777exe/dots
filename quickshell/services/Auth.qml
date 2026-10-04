pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Polkit



Singleton {
    id: root

    
    
    property bool available: agent.isRegistered

    
    
    
    
    property var pending: {
        const f = agent.flow;
        if (!f) return null;

        
        
        
        
        
        
        
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
            
            
            
            errorText: f.supplementaryIsError ? f.supplementaryMessage : "",
            
            supplementaryMessage: f.supplementaryMessage,
            supplementaryIsError: f.supplementaryIsError
        };
    }

    
    
    property var prevPending: null

    onPendingChanged: {
        const prev = root.prevPending;
        const next = root.pending;

        
        if (!prev && next) {
            root.requestBegan(next);
        }
        
        
        
        
        
        
        
        
        else if (prev && next && prev.cookie !== next.cookie) {
            root.requestBegan(next);
        }

        root.prevPending = next;
    }

    signal requestBegan(var request)

    PolkitAgent {
        id: agent

        
        
        
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
