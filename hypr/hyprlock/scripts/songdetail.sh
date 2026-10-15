#!/bin/sh

song_info=$(playerctl metadata --format '{{title}}      {{artist}}' 2>/dev/null) || song_info=""

echo "$song_info" 