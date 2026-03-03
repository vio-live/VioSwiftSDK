#!/bin/bash
cd /tmp/VioSwiftSDK
git add Sources/VioCore/Managers/CampaignWebSocketManager.swift Sources/VioEngagementSystem/Managers/EngagementManager.swift
git commit -m "feat(engagement): handle poll/contest WS events in CampaignWebSocketManager (#161)

- Add poll and contest case handlers in handleMessage()
- Filter events by CampaignManager.shared.currentBroadcastContext.broadcastId
- Bridge to EngagementManager via static closures (cross-module)
- Add addOrUpdatePoll/addOrUpdateContest on EngagementManager
- Register WS handlers at EngagementManager init"
git log -1 --oneline
