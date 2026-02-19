//
//  TimelineDataGenerator.swift
//  Viaplay
//
//  Pre-generated timeline data for Barcelona - PSG match
//  All events synchronized with video timestamps
//

import Foundation
import SwiftUI
import VioCore
import VioDesignSystem

struct TimelineDataGenerator {
    
    /// Generate complete timeline for Barcelona - PSG match
    static func generateBarcelonaPSGTimeline() -> [AnyTimelineEvent] {
        var events: [AnyTimelineEvent] = []
        
        // MARK: - Pre-Match Events (before kickoff)
        
        // -5' - Barcelona Lineup
        events.append(AnyTimelineEvent(AnnouncementEvent(
            id: "lineup-barcelona",
            videoTimestamp: -300,  // 5 minutes before kickoff
            title: "Oppstilling Barcelona",
            message: "Startoppstilling for Barcelona",
            imageUrl: nil,
            actionUrl: nil,
            actionText: nil,
            metadata: ["type": "lineup", "team": "home", "formation": "4-3-3"]
        )))
        
        // -3' - PSG Lineup
        events.append(AnyTimelineEvent(AnnouncementEvent(
            id: "lineup-psg",
            videoTimestamp: -180,  // 3 minutes before kickoff
            title: "Oppstilling PSG",
            message: "Startoppstilling for PSG",
            imageUrl: nil,
            actionUrl: nil,
            actionText: nil,
            metadata: ["type": "lineup", "team": "away", "formation": "4-4-2"]
        )))
        
        // -1' - Match Preview
        events.append(AnyTimelineEvent(AnnouncementEvent(
            id: "match-preview",
            videoTimestamp: -60,  // 1 minute before kickoff
            title: "Kampen starter snart!",
            message: "Barcelona mot PSG - Champions League",
            imageUrl: nil,
            actionUrl: nil,
            actionText: nil,
            metadata: ["type": "preview"]
        )))
        
        // MARK: - Match Events
        
        // 0' - Kick Off (Announcement style)
        events.append(AnyTimelineEvent(AnnouncementEvent(
            id: "kickoff",
            videoTimestamp: 0,
            title: "⚽ Avspark",
            message: "Kampen starter! Barcelona vs PSG",
            imageUrl: nil,
            actionUrl: nil,
            actionText: nil,
            metadata: ["type": "kickoff"]
        )))
        
        // 5' - Substitution
        events.append(AnyTimelineEvent(MatchSubstitutionEvent(
            id: "sub-5",
            videoTimestamp: 300,  // 5 * 60
            playerIn: "A. Scott",
            playerOut: "T. Adams",
            team: .away,
            metadata: nil
        )))
        
        // 13' - GOL A. Diallo + Commentary
        events.append(AnyTimelineEvent(MatchGoalEvent(
            id: "goal-13",
            videoTimestamp: 780,
            player: "A. Diallo",
            team: .home,
            score: "1-0",
            assistBy: "Bruno Fernandes",
            isOwnGoal: false,
            isPenalty: false,
            metadata: nil
        )))
        
        // Goal commentary (sin crear el evento, ya usaremos admin comment existente)
        
        // 18' - Yellow Card
        events.append(AnyTimelineEvent(MatchCardEvent(
            id: "card-18",
            videoTimestamp: 1080,  // 18 * 60
            player: "Casemiro",
            team: .home,
            cardType: .yellow,
            reason: "Falta táctica",
            metadata: nil
        )))
        
        // 25' - Yellow Card
        events.append(AnyTimelineEvent(MatchCardEvent(
            id: "card-25",
            videoTimestamp: 1500,  // 25 * 60
            player: "M. Tavernier",
            team: .away,
            cardType: .yellow,
            reason: nil,
            metadata: nil
        )))
        
        // 32' - GOL B. Mbeumo
        events.append(AnyTimelineEvent(MatchGoalEvent(
            id: "goal-32",
            videoTimestamp: 1920,  // 32 * 60
            player: "B. Mbeumo",
            team: .home,
            score: "2-0",
            assistBy: "Diogo Dalot",
            isOwnGoal: false,
            isPenalty: false,
            metadata: nil
        )))
        
        // 44' - Before halftime
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-44",
            videoTimestamp: 2640,
            minute: 44,
            text: "Dean Huijsen (Real Madrid) finds some space inside the box to connect with the resulting corner kick. He sends a fine header towards the top right corner, but one of the defenders deflect it onto the post. Maybe next time.",
            commentaryType: .corner,
            isHighlighted: false,
            metadata: nil
        )))
        
        // 45' - Goal commentary
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-45-goal",
            videoTimestamp: 2700,
            minute: 45,
            text: "Goal! Pedri gets to the ball, slips Robert Lewandowski (Barcelona) into the area and he scores with a delightful chipped finish to make it 2-1.",
            commentaryType: .goal,
            isHighlighted: true,
            metadata: nil
        )))
        
        // 45+6' - Chance
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-45-6-chance",
            videoTimestamp: 2760,
            minute: 45,
            text: "Gonzalo Garcia (Real Madrid) is the first to get to a rebound inside the penalty area and his weak, but precise effort finds its way into the back of the net, bouncing in off the crossbar.",
            commentaryType: .goal,
            isHighlighted: true,
            metadata: nil
        )))
        
        // 45+8' - Halftime
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-45-8",
            videoTimestamp: 2780,
            minute: 45,
            text: "3 min. of stoppage-time to be played.",
            commentaryType: .halftime,
            isHighlighted: false,
            metadata: nil
        )))
        
        // 45' - Half Time
        events.append(AnyTimelineEvent(AnnouncementEvent(
            id: "halftime",
            videoTimestamp: 2700,
            title: "Pause",
            message: "Første omgang ferdig",
            imageUrl: nil,
            actionUrl: nil,
            actionText: nil,
            metadata: ["type": "halftime"]
        )))
        
        // MARK: - Casting Events (during halftime break) - from DemoDataManager config
        
        let dm = DemoDataManager.shared
        let contests = dm.timelineCastingContests
        let products = dm.timelineCastingProducts
        
        if contests.count > 0 {
            let c = contests[0]
            let contestType: CastingContestEvent.ContestType = c.contestType.lowercased() == "giveaway" ? .giveaway : .quiz
            events.append(AnyTimelineEvent(CastingContestEvent(
                id: c.id,
                videoTimestamp: TimeInterval(c.videoTimestamp),
                title: c.title,
                description: c.description,
                prize: c.prize,
                contestType: contestType,
                metadata: ["imageAsset": c.imageAsset],
                broadcastContext: nil
            )))
        }
        
        if let chatUser = dm.chatUsername(at: 1) {
            events.append(AnyTimelineEvent(ChatMessageEvent(
                videoTimestamp: 2725,
                username: chatUser.name,
                text: "Dette er en fantastisk mulighet! 🎁",
                usernameColor: Color(hex: chatUser.color),
                likes: 12
            )))
        }
        
        if let social = dm.socialAccount(at: 0) {
            events.append(AnyTimelineEvent(TweetEvent(
                id: dm.tweetHalftime1EventId,
                videoTimestamp: 2730,
                authorName: social.name,
                authorHandle: social.handle,
                authorAvatar: nil,
                tweetText: "Ikke gå glipp av våre eksklusive tilbud under kampen! 🛒⚽",
                isVerified: social.verified,
                likes: 234,
                retweets: 89,
                metadata: nil
            )))
        }
        
        if contests.count > 1 {
            let c = contests[1]
            let contestType: CastingContestEvent.ContestType = c.contestType.lowercased() == "giveaway" ? .giveaway : .quiz
            events.append(AnyTimelineEvent(CastingContestEvent(
                id: c.id,
                videoTimestamp: TimeInterval(c.videoTimestamp),
                title: c.title,
                description: c.description,
                prize: c.prize,
                contestType: contestType,
                metadata: ["imageAsset": c.imageAsset],
                broadcastContext: nil
            )))
        }
        
        if let chatUser = dm.chatUsername(at: 2) {
            events.append(AnyTimelineEvent(ChatMessageEvent(
                videoTimestamp: 2755,
                username: chatUser.name,
                text: "Billetter til Champions League?! Jeg må delta! 🎫",
                usernameColor: Color(hex: chatUser.color),
                likes: 18
            )))
        }
        
        if let social = dm.socialAccount(at: 1) {
            events.append(AnyTimelineEvent(TweetEvent(
                id: dm.tweetHalftime2EventId,
                videoTimestamp: 2760,
                authorName: social.name,
                authorHandle: social.handle,
                authorAvatar: nil,
                tweetText: "Spennende konkurranser under pausen! Delta nå! 🏆",
                isVerified: social.verified,
                likes: 456,
                retweets: 123,
                metadata: nil
            )))
        }
        
        if products.count > 0 {
            let p = products[0]
            let productUrl = dm.productUrl(for: p.productId)
            let checkoutUrl = dm.checkoutUrl(for: p.productId)
            events.append(AnyTimelineEvent(CastingProductEvent(
                id: p.id,
                videoTimestamp: TimeInterval(p.videoTimestamp),
                productId: p.productId,
                productIds: p.productIds.isEmpty ? nil : p.productIds,
                title: p.title,
                description: p.description,
                castingProductUrl: productUrl,
                castingCheckoutUrl: checkoutUrl,
                imageAsset: nil,
                metadata: nil
            )))
        }
        
        if let chatUser = dm.chatUsername(at: 3) {
            events.append(AnyTimelineEvent(ChatMessageEvent(
                videoTimestamp: 2775,
                username: chatUser.name,
                text: "25% rabatt?! Dette må jeg sjekke ut! 📺",
                usernameColor: Color(hex: chatUser.color),
                likes: 9
            )))
        }
        
        // MARK: - Casting Products (moved to halftime)
        
        // MARK: - Chat Messages (Sincronizados con eventos)
        
        // MARK: - Pre-Match & Commentary
        
        // -4' - Pre-match commentary
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-prematch",
            videoTimestamp: -240,  // 4 minutes before kickoff
            minute: 0,
            text: "Hello, welcome to our live play-by-play commentaries. You will be able to see a written form of all the interesting moments of the game, so you won't miss a thing. Sit back and have fun.",
            commentaryType: .general,
            isHighlighted: false,
            metadata: nil
        )))
        
        // -2' - Pre-match chat
        events.append(AnyTimelineEvent(ChatMessageEvent(
            videoTimestamp: -120,
            username: "SportsFan23",
            text: "Snart starter kampen! 🔥",
            usernameColor: .cyan,
            likes: 5
        )))
        
        // -1'30" - Pre-match commentary
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-supervisor",
            videoTimestamp: -90,
            minute: 0,
            text: "Jose Munuera will supervise the game today.",
            commentaryType: .general,
            isHighlighted: false,
            metadata: nil
        )))
        
        // -30" - Pre-match chat
        events.append(AnyTimelineEvent(ChatMessageEvent(
            videoTimestamp: -30,
            username: "MatchMaster",
            text: "Dette blir en episk kamp!",
            usernameColor: .orange,
            likes: 8
        )))
        
        // 1' - Kickoff commentary
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-1-kickoff",
            videoTimestamp: 60,
            minute: 1,
            text: "The first half of this match is about to start.",
            commentaryType: .kickoff,
            isHighlighted: false,
            metadata: nil
        )))
        
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-1-start",
            videoTimestamp: 65,
            minute: 1,
            text: "Barcelona will kick the game off.",
            commentaryType: .kickoff,
            isHighlighted: false,
            metadata: nil
        )))
        
        // 1' - Tackle
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-1-tackle",
            videoTimestamp: 70,
            minute: 1,
            text: "Jose Munuera blows his whistle after Eduardo Camavinga (Real Madrid) brings one of his opponents down with a strong tackle.",
            commentaryType: .foul,
            isHighlighted: false,
            metadata: nil
        )))
        
        // 3' - Pass
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-3",
            videoTimestamp: 180,
            minute: 3,
            text: "Fermín (Barcelona) slides a pass forward, but one of the defenders cuts it out.",
            commentaryType: .general,
            isHighlighted: false,
            metadata: nil
        )))
        
        // 4' - Foul
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-4",
            videoTimestamp: 240,
            minute: 4,
            text: "Alvaro Carreras (Real Madrid) makes a rough challenge and the referee blows for a foul.",
            commentaryType: .foul,
            isHighlighted: false,
            metadata: nil
        )))
        
        // 5' - Chance
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-5",
            videoTimestamp: 300,
            minute: 5,
            text: "Another attempt to send the ball beyond the defence by Pedri (Barcelona) is thwarted and cleared to safety.",
            commentaryType: .chance,
            isHighlighted: false,
            metadata: nil
        )))
        
        // 6' - Chance
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-6",
            videoTimestamp: 360,
            minute: 6,
            text: "Jules Kounde (Barcelona) whips the ball into the penalty area, but one of the defenders is alert and spanks it away.",
            commentaryType: .chance,
            isHighlighted: false,
            metadata: nil
        )))
        
        // 8' - Corner
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-8-corner",
            videoTimestamp: 480,
            minute: 8,
            text: "Rodrygo (Real Madrid) attempts to find a teammate with the corner, but the effort is snuffed out by the goalkeeper.",
            commentaryType: .corner,
            isHighlighted: false,
            metadata: nil
        )))
        
        // 11' - Chance
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-11",
            videoTimestamp: 660,
            minute: 11,
            text: "Alejandro Balde (Barcelona) did his best to latch on to a crossfield pass, but it was too long and it goes out of play.",
            commentaryType: .general,
            isHighlighted: false,
            metadata: nil
        )))
        
        // 0'45" - Chat inicial
        events.append(AnyTimelineEvent(ChatMessageEvent(
            videoTimestamp: 45,
            username: "SportsFan23",
            text: "Endelig! La oss gå! 🔥",
            usernameColor: .cyan
        )))
        
        events.append(AnyTimelineEvent(ChatMessageEvent(
            videoTimestamp: 90,
            username: "MatchMaster",
            text: "Dette blir en god kamp!",
            usernameColor: .orange
        )))
        
        // 2' - Chats tempranos
        events.append(AnyTimelineEvent(ChatMessageEvent(
            videoTimestamp: 120,
            username: "GoalKeeper",
            text: "Vamos Barcelona! 💪",
            usernameColor: .green
        )))
        
        // 5'30" - Después del cambio
        events.append(AnyTimelineEvent(ChatMessageEvent(
            videoTimestamp: 330,
            username: "TacticsGuru",
            text: "Interessant bytte så tidlig",
            usernameColor: .teal
        )))
        
        // 46' - Second half start
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-46",
            videoTimestamp: 2760,
            minute: 46,
            text: "The whistle blows and Jose Munuera starts the second half.",
            commentaryType: .kickoff,
            isHighlighted: false,
            metadata: nil
        )))
        
        // 46' - Foul
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-46-foul",
            videoTimestamp: 2780,
            minute: 46,
            text: "Frenkie de Jong (Barcelona) makes a rough challenge and Jose Munuera blows his whistle for a foul.",
            commentaryType: .foul,
            isHighlighted: false,
            metadata: nil
        )))
        
        // 47' - Corner
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-47",
            videoTimestamp: 2820,
            minute: 47,
            text: "Vinicius Junior (Real Madrid) sends a pass into the penalty area, but the opponent manages to cut it out. Real Madrid will have a chance to score from a corner.",
            commentaryType: .corner,
            isHighlighted: false,
            metadata: nil
        )))
        
        // 48' - Chance
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-48",
            videoTimestamp: 2880,  // 48 * 60
            minute: 48,
            text: "Robert Lewandowski (Barcelona) finds himself in a good position inside the box and shoots, but his effort goes just wide of the left post.",
            commentaryType: .chance,
            isHighlighted: false,
            metadata: nil
        )))
        
        // 48'30" - Chat
        events.append(AnyTimelineEvent(ChatMessageEvent(
            videoTimestamp: 2910,
            username: "StrikerKing",
            text: "Så nærme! Nesten 3-0!",
            usernameColor: .pink,
            likes: 5
        )))
        
        // 50' - Foul
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-50",
            videoTimestamp: 3000,  // 50 * 60
            minute: 50,
            text: "Aurelien Tchouameni (Real Madrid) commits a foul and the referee stops play.",
            commentaryType: .foul,
            isHighlighted: false,
            metadata: nil
        )))
        
        // 50' - Yellow Card
        events.append(AnyTimelineEvent(MatchCardEvent(
            id: "card-50",
            videoTimestamp: 3005,
            player: "Aurelien Tchouameni",
            team: .away,
            cardType: .yellow,
            reason: "Foul",
            metadata: nil
        )))
        
        // 52' - Substitution
        events.append(AnyTimelineEvent(MatchSubstitutionEvent(
            id: "sub-52",
            videoTimestamp: 3120,  // 52 * 60
            playerIn: "Rodrygo",
            playerOut: "Vinicius Junior",
            team: .away,
            metadata: nil
        )))
        
        // 52'30" - Chat after substitution
        events.append(AnyTimelineEvent(ChatMessageEvent(
            videoTimestamp: 3150,
            username: "TacticsGuru",
            text: "Interessant bytte fra PSG",
            usernameColor: .teal,
            likes: 3
        )))
        
        // 54' - Chance
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-54",
            videoTimestamp: 3240,  // 54 * 60
            minute: 54,
            text: "Pedri (Barcelona) tries his luck from distance, but his shot is blocked by one of the defenders.",
            commentaryType: .chance,
            isHighlighted: false,
            metadata: nil
        )))
        
        // 55' - Tweet
        events.append(AnyTimelineEvent(TweetEvent(
            id: "tweet-55",
            videoTimestamp: 3300,  // 55 * 60
            authorName: "Barcelona",
            authorHandle: "@FCBarcelona",
            authorAvatar: nil,
            tweetText: "Fortsetter å presse på! 💪🔵🔴",
            isVerified: true,
            likes: 3456,
            retweets: 1234,
            metadata: nil
        )))
        
        // 56' - Corner
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-56",
            videoTimestamp: 3360,  // 56 * 60
            minute: 56,
            text: "Barcelona win a corner. Pedri will take it.",
            commentaryType: .corner,
            isHighlighted: false,
            metadata: nil
        )))
        
        // 57' - Chat
        events.append(AnyTimelineEvent(ChatMessageEvent(
            videoTimestamp: 3420,
            username: "MatchMaster",
            text: "Barcelona kontrollerer kampen nå",
            usernameColor: .orange,
            likes: 7
        )))
        
        // 58' - Save
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-58",
            videoTimestamp: 3480,  // 58 * 60
            minute: 58,
            text: "Fantastic save! Ter Stegen (Barcelona) makes an incredible stop to deny Rodrygo (Real Madrid) from close range.",
            commentaryType: .save,
            isHighlighted: true,
            metadata: nil
        )))
        
        // 58'15" - Chat after save
        events.append(AnyTimelineEvent(ChatMessageEvent(
            videoTimestamp: 3495,
            username: "GoalKeeper",
            text: "FOR EN REDNING!!! 🧤",
            usernameColor: .green,
            likes: 23
        )))
        
        // 60' - Stats update
        events.append(AnyTimelineEvent(StatisticsUpdateEvent(
            id: "stats-60",
            videoTimestamp: 3600,  // 60 * 60
            statName: "Skudd totalt",
            homeValue: 12,
            awayValue: 6,
            metadata: nil
        )))
        
        // 60' - Tweet
        events.append(AnyTimelineEvent(TweetEvent(
            id: "tweet-60",
            videoTimestamp: 3605,
            authorName: "PSG",
            authorHandle: "@PSG_inside",
            authorAvatar: nil,
            tweetText: "Vi må score snart! Allez Paris! 🔴🔵",
            isVerified: true,
            likes: 2345,
            retweets: 987,
            metadata: nil
        )))
        
        // 62' - Foul
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-62",
            videoTimestamp: 3720,  // 62 * 60
            minute: 62,
            text: "Foul by Frenkie de Jong (Barcelona). Real Madrid have a free kick in a dangerous position.",
            commentaryType: .foul,
            isHighlighted: false,
            metadata: nil
        )))
        
        // 63' - Chance
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-63",
            videoTimestamp: 3780,  // 63 * 60
            minute: 63,
            text: "The free kick is taken and the ball finds its way to Marquinhos (Real Madrid), but his header goes over the crossbar.",
            commentaryType: .chance,
            isHighlighted: false,
            metadata: nil
        )))
        
        // 64' - Chat
        events.append(AnyTimelineEvent(ChatMessageEvent(
            videoTimestamp: 3840,
            username: "DefenderPro",
            text: "Nesten! Så nærme mål",
            usernameColor: .blue,
            likes: 4
        )))
        
        // 65' - Substitution
        events.append(AnyTimelineEvent(MatchSubstitutionEvent(
            id: "sub-65",
            videoTimestamp: 3900,  // 65 * 60
            playerIn: "Gavi",
            playerOut: "Pedri",
            team: .home,
            metadata: nil
        )))
        
        // 66' - Corner
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-66",
            videoTimestamp: 3960,  // 66 * 60
            minute: 66,
            text: "Corner kick for Barcelona. Gavi will take it.",
            commentaryType: .corner,
            isHighlighted: false,
            metadata: nil
        )))
        
        // 67' - Chance
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-67",
            videoTimestamp: 4020,  // 67 * 60
            minute: 67,
            text: "The corner is cleared, but Barcelona regain possession and create another chance. The shot goes wide.",
            commentaryType: .chance,
            isHighlighted: false,
            metadata: nil
        )))
        
        // 68' - Chat
        events.append(AnyTimelineEvent(ChatMessageEvent(
            videoTimestamp: 4080,
            username: "CoachView",
            text: "Barcelona har mange sjanser",
            usernameColor: .indigo,
            likes: 6
        )))
        
        // 70' - Stats update
        events.append(AnyTimelineEvent(StatisticsUpdateEvent(
            id: "stats-70",
            videoTimestamp: 4200,  // 70 * 60
            statName: "Ball i besittelse",
            homeValue: 62.3,
            awayValue: 37.7,
            metadata: nil
        )))
        
        // 70' - Tweet
        events.append(AnyTimelineEvent(TweetEvent(
            id: "tweet-70",
            videoTimestamp: 4205,
            authorName: "ESPN FC",
            authorHandle: "@ESPNFC",
            authorAvatar: nil,
            tweetText: "Barcelona dominating possession in the second half. Can PSG find a way back? ⚽",
            isVerified: true,
            likes: 5678,
            retweets: 2345,
            metadata: nil
        )))
        
        // 72' - Yellow Card
        events.append(AnyTimelineEvent(MatchCardEvent(
            id: "card-72",
            videoTimestamp: 4320,  // 72 * 60
            player: "Gavi",
            team: .home,
            cardType: .yellow,
            reason: "Foul",
            metadata: nil
        )))
        
        // 72'30" - Chat
        events.append(AnyTimelineEvent(ChatMessageEvent(
            videoTimestamp: 4350,
            username: "FutbolLoco",
            text: "Gavi fikk gult kort",
            usernameColor: .yellow,
            likes: 2
        )))
        
        // 74' - Chance
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-74",
            videoTimestamp: 4440,  // 74 * 60
            minute: 74,
            text: "Robert Lewandowski (Barcelona) receives the ball inside the box and shoots, but the goalkeeper makes a comfortable save.",
            commentaryType: .chance,
            isHighlighted: false,
            metadata: nil
        )))
        
        // 75' - Admin comment
        events.append(AnyTimelineEvent(AdminCommentEvent(
            id: "admin-75",
            videoTimestamp: 4500,  // 75 * 60
            adminName: "Magnus Drivenes",
            comment: "15 minutter igjen. PSG må score snart hvis de skal ha håp om å snu kampen.",
            isPinned: false,
            metadata: nil
        )))
        
        // 76' - Corner
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-76",
            videoTimestamp: 4560,  // 76 * 60
            minute: 76,
            text: "Another corner for Barcelona. They're really pushing for a third goal.",
            commentaryType: .corner,
            isHighlighted: false,
            metadata: nil
        )))
        
        // 77' - Chat
        events.append(AnyTimelineEvent(ChatMessageEvent(
            videoTimestamp: 4620,
            username: "UltrasGroup",
            text: "Vi trenger enda et mål!",
            usernameColor: .red,
            likes: 11
        )))
        
        // 78' - Substitution
        events.append(AnyTimelineEvent(MatchSubstitutionEvent(
            id: "sub-78",
            videoTimestamp: 4680,  // 78 * 60
            playerIn: "Raphinha",
            playerOut: "B. Mbeumo",
            team: .home,
            metadata: nil
        )))
        
        // 79' - Chance
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-79",
            videoTimestamp: 4740,  // 79 * 60
            minute: 79,
            text: "Raphinha (Barcelona) makes a great run down the wing and sends in a cross, but no one can get on the end of it.",
            commentaryType: .chance,
            isHighlighted: false,
            metadata: nil
        )))
        
        // 80' - Tweet
        events.append(AnyTimelineEvent(TweetEvent(
            id: "tweet-80",
            videoTimestamp: 4800,  // 80 * 60
            authorName: "UEFA Champions League",
            authorHandle: "@ChampionsLeague",
            authorAvatar: nil,
            tweetText: "10 minutes remaining! Can PSG mount a comeback? 🏆⚽",
            isVerified: true,
            likes: 8912,
            retweets: 3456,
            metadata: nil
        )))
        
        // 81' - Foul
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-81",
            videoTimestamp: 4860,  // 81 * 60
            minute: 81,
            text: "Foul by Marquinhos (Real Madrid). Barcelona have a free kick in a good position.",
            commentaryType: .foul,
            isHighlighted: false,
            metadata: nil
        )))
        
        // 82' - Chance
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-82",
            videoTimestamp: 4920,  // 82 * 60
            minute: 82,
            text: "The free kick is taken and the ball finds its way to Araújo (Barcelona), but his header is saved by the goalkeeper.",
            commentaryType: .chance,
            isHighlighted: false,
            metadata: nil
        )))
        
        // 82'30" - Chat
        events.append(AnyTimelineEvent(ChatMessageEvent(
            videoTimestamp: 4950,
            username: "TeamCaptain",
            text: "Så nærme igjen!",
            usernameColor: .red,
            likes: 8
        )))
        
        // 84' - Yellow Card
        events.append(AnyTimelineEvent(MatchCardEvent(
            id: "card-84",
            videoTimestamp: 5040,  // 84 * 60
            player: "Marquinhos",
            team: .away,
            cardType: .yellow,
            reason: "Foul",
            metadata: nil
        )))
        
        // 85' - Stats update
        events.append(AnyTimelineEvent(StatisticsUpdateEvent(
            id: "stats-85",
            videoTimestamp: 5100,  // 85 * 60
            statName: "Skudd på mål",
            homeValue: 8,
            awayValue: 4,
            metadata: nil
        )))
        
        // 86' - Corner
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-86",
            videoTimestamp: 5160,  // 86 * 60
            minute: 86,
            text: "Corner kick for Real Madrid. This could be their last chance.",
            commentaryType: .corner,
            isHighlighted: false,
            metadata: nil
        )))
        
        // 87' - Chat
        events.append(AnyTimelineEvent(ChatMessageEvent(
            videoTimestamp: 5220,
            username: "FanZone",
            text: "Kun 3 minutter igjen!",
            usernameColor: .orange,
            likes: 5
        )))
        
        // 88' - Chance
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-88",
            videoTimestamp: 5280,  // 88 * 60
            minute: 88,
            text: "Rodrygo (Real Madrid) gets a chance from inside the box, but his shot is blocked by the defense.",
            commentaryType: .chance,
            isHighlighted: false,
            metadata: nil
        )))
        
        // 89' - Tweet
        events.append(AnyTimelineEvent(TweetEvent(
            id: "tweet-89",
            videoTimestamp: 5340,  // 89 * 60
            authorName: "Fabrizio Romano",
            authorHandle: "@FabrizioRomano",
            authorAvatar: nil,
            tweetText: "Barcelona looking comfortable with this lead. PSG running out of time! ⏱️",
            isVerified: true,
            likes: 4567,
            retweets: 1890,
            metadata: nil
        )))
        
        // 90' - Full Time announcement
        events.append(AnyTimelineEvent(AnnouncementEvent(
            id: "fulltime",
            videoTimestamp: 5400,  // 90 * 60
            title: "Fulltid",
            message: "Kampen er ferdig! Barcelona vinner 2-0",
            imageUrl: nil,
            actionUrl: nil,
            actionText: nil,
            metadata: ["type": "fulltime"]
        )))
        
        // 90+2' - Commentary
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-90-2",
            videoTimestamp: 5520,  // 90*60 + 2*60
            minute: 90,
            text: "The referee blows the final whistle. Barcelona win 2-0!",
            commentaryType: .general,
            isHighlighted: true,
            metadata: nil
        )))
        
        // 90+2' - Chat after match
        events.append(AnyTimelineEvent(ChatMessageEvent(
            videoTimestamp: 5525,
            username: "SportsFan23",
            text: "Fantastisk kamp! Barcelona fortjente seieren! 🏆",
            usernameColor: .cyan,
            likes: 34
        )))
        
        // 90+2' - Tweet after match
        events.append(AnyTimelineEvent(TweetEvent(
            id: "tweet-fulltime",
            videoTimestamp: 5530,
            authorName: "Barcelona",
            authorHandle: "@FCBarcelona",
            authorAvatar: nil,
            tweetText: "FULLTID! Vi vinner 2-0! Takk til alle fans! 🔵🔴🏆",
            isVerified: true,
            likes: 12345,
            retweets: 5678,
            metadata: nil
        )))
        
        // 13'05" - JUSTO DESPUÉS DEL GOL
        events.append(AnyTimelineEvent(ChatMessageEvent(
            videoTimestamp: 785,
            username: "FutbolLoco",
            text: "GOOOOOL!!! 🎉🎉🎉",
            usernameColor: .yellow,
            likes: 45
        )))
        
        events.append(AnyTimelineEvent(ChatMessageEvent(
            videoTimestamp: 787,
            username: "TeamCaptain",
            text: "Hvilken pasning fra Bruno!",
            usernameColor: .red,
            likes: 32
        )))
        
        events.append(AnyTimelineEvent(ChatMessageEvent(
            videoTimestamp: 790,
            username: "DefenderPro",
            text: "Utrolig avslutning! ⚽",
            usernameColor: .blue,
            likes: 28
        )))
        
        // 15' - Chat durante el partido
        events.append(AnyTimelineEvent(ChatMessageEvent(
            videoTimestamp: 900,
            username: "StrikerKing",
            text: "Barcelona dominerer helt",
            usernameColor: .pink
        )))
        
        // 20' - Más chats
        events.append(AnyTimelineEvent(ChatMessageEvent(
            videoTimestamp: 1200,
            username: "CoachView",
            text: "Taktikken fungerer perfekt",
            usernameColor: .indigo
        )))
        
        // 32'10" - DESPUÉS DEL SEGUNDO GOL
        events.append(AnyTimelineEvent(ChatMessageEvent(
            videoTimestamp: 1930,
            username: "UltrasGroup",
            text: "ENDA ET MÅL!!! 🔥🔥",
            usernameColor: .red,
            likes: 67
        )))
        
        events.append(AnyTimelineEvent(ChatMessageEvent(
            videoTimestamp: 1935,
            username: "FanZone",
            text: "Dette er gull!",
            usernameColor: .orange,
            likes: 54
        )))
        
        // MARK: - Polls (en momentos específicos)
        
        // 7' - Concurso (Contest)
        events.append(AnyTimelineEvent(AnnouncementEvent(
            id: "contest-7",
            videoTimestamp: 420,  // 7 minutos
            title: "🏆 Vinn en drakt fra ditt favorittlag!",
            message: "Delta i konkurransen og få sjansen til å vinne en signert drakt fra XXL Sports.",
            imageUrl: nil,
            actionUrl: nil,
            actionText: "Delta",
            metadata: ["type": "contest", "prize": "Fotballdrakt"]
        )))
        
        // 10' - Poll sobre resultado
        events.append(AnyTimelineEvent(PollTimelineEvent(
            id: "poll-10",
            videoTimestamp: 600,
            question: "Hvem vinner denne kampen?",
            options: [
                .init(id: "opt1", text: "Barcelona", voteCount: 3456, percentage: 65),
                .init(id: "opt2", text: "Real Madrid", voteCount: 1234, percentage: 23),
                .init(id: "opt3", text: "Uavgjort", voteCount: 645, percentage: 12)
            ],
            duration: 600,
            endTimestamp: 1200,
            metadata: nil,
            broadcastContext: nil
        )))
        
        // 20' - Poll sobre neste mål
        events.append(AnyTimelineEvent(PollTimelineEvent(
            id: "poll-20",
            videoTimestamp: 1200,
            question: "Hvem scorer neste mål?",
            options: [
                .init(id: "opt1", text: "Barcelona", voteCount: 2890, percentage: 58),
                .init(id: "opt2", text: "Real Madrid", voteCount: 1567, percentage: 31),
                .init(id: "opt3", text: "Ingen flere mål", voteCount: 543, percentage: 11)
            ],
            duration: 900,
            endTimestamp: 2100,
            metadata: nil,
            broadcastContext: nil
        )))
        
        // 35' - Poll sobre beste spiller
        events.append(AnyTimelineEvent(PollTimelineEvent(
            id: "poll-35",
            videoTimestamp: 2100,
            question: "Hvem er beste spiller så langt?",
            options: [
                .init(id: "opt1", text: "A. Diallo", voteCount: 2345, percentage: 45),
                .init(id: "opt2", text: "Bruno Fernandes", voteCount: 1789, percentage: 34),
                .init(id: "opt3", text: "B. Mbeumo", voteCount: 1098, percentage: 21)
            ],
            duration: 600,
            endTimestamp: 2700,
            metadata: nil,
            broadcastContext: nil
        )))
        
        // MARK: - Tweets (en momentos clave)
        
        // 2' - Tweet al inicio (Luka Modrić - Real Madrid)
        events.append(AnyTimelineEvent(TweetEvent(
            id: "tweet-2",
            videoTimestamp: 120,
            authorName: "Luka Modrić",
            authorHandle: "@LukaModric10",
            authorAvatar: "https://pbs.twimg.com/profile_images/1467838580013015046/Ri-Mx4k0_400x400.jpg",
            tweetText: "Nikada ne odustaj! ⚽🔥 #ChampionsLeague",
            isVerified: true,
            likes: 1345,
            retweets: 878,
            metadata: nil
        )))
        
        // 8' - Otro tweet (Erling Haaland - Manchester City)
        events.append(AnyTimelineEvent(TweetEvent(
            id: "tweet-8",
            videoTimestamp: 480,
            authorName: "Erling Haaland",
            authorHandle: "@ErlingHaaland",
            authorAvatar: "https://pbs.twimg.com/profile_images/1618611381585408002/yvY87tJm_400x400.jpg",
            tweetText: "Alltid klar for neste mål! ⚽🎯",
            isVerified: true,
            likes: 2340,
            retweets: 1456,
            metadata: nil
        )))
        
        // 13'30" - Tweet después del gol (Kylian Mbappé - PSG/Real Madrid)
        events.append(AnyTimelineEvent(TweetEvent(
            id: "tweet-13",
            videoTimestamp: 810,
            authorName: "Kylian Mbappé",
            authorHandle: "@KMbappe",
            authorAvatar: "https://pbs.twimg.com/profile_images/1654969131244240896/rCJEZU4q_400x400.jpg",
            tweetText: "Champions League! C'est magnifique! ⚡🔥",
            isVerified: true,
            likes: 4567,
            retweets: 2123,
            metadata: nil
        )))
        
        // 20' - Tweet de Cristiano Ronaldo
        events.append(AnyTimelineEvent(TweetEvent(
            id: "tweet-20",
            videoTimestamp: 1200,
            authorName: "Cristiano Ronaldo",
            authorHandle: "@Cristiano",
            authorAvatar: "https://pbs.twimg.com/profile_images/1594446880498401282/o4L2z8Yw_400x400.jpg",
            tweetText: "Grande Champions League! Siuuu! 🔥⚽",
            isVerified: true,
            likes: 8910,
            retweets: 3456,
            metadata: nil
        )))
        
        // MARK: - Highlights (con videos de Firebase)
        
        // 13' - Highlight del gol de Diallo
        events.append(AnyTimelineEvent(HighlightTimelineEvent(
            id: "highlight-goal-13",
            videoTimestamp: 780,  // 13 minutos
            title: "MÅL: A. Diallo",
            description: "Nydelig avslutning fra Diallo!",
            thumbnailUrl: nil,
            clipUrl: "https://firebasestorage.googleapis.com/v0/b/tipio-1ec97.appspot.com/o/1.MP4?alt=media&token=898b7836-5e27-492d-82bb-9d7bb50f9d66",
            highlightType: .goal,
            metadata: ["score": "1-0", "player": "A. Diallo"]
        )))
        
        // 25' - Highlight de ocasión
        events.append(AnyTimelineEvent(HighlightTimelineEvent(
            id: "highlight-chance-25",
            videoTimestamp: 1500,  // 25 minutos
            title: "Stor sjanse!",
            description: "Nesten 2-0 for Barcelona!",
            thumbnailUrl: nil,
            clipUrl: "https://firebasestorage.googleapis.com/v0/b/tipio-1ec97.appspot.com/o/2.MP4?alt=media&token=9011a94a-1085-4b69-bd41-3b1432ca577a",
            highlightType: .chance,
            metadata: ["team": "home"]
        )))
        
        // 18' - Highlight de tarjeta amarilla
        events.append(AnyTimelineEvent(HighlightTimelineEvent(
            id: "highlight-card-18",
            videoTimestamp: 1080,  // 18 minutos
            title: "Gult kort: Casemiro",
            description: "Falta táctica fra Casemiro",
            thumbnailUrl: nil,
            clipUrl: "https://firebasestorage.googleapis.com/v0/b/tipio-1ec97.appspot.com/o/3.MP4?alt=media&token=f28dadf8-05df-4544-a21f-a4c45836793f",
            highlightType: .yellowCard,
            metadata: ["player": "Casemiro", "team": "home"]
        )))
        
        // MARK: - Products (en momentos específicos)
        
        // 20' - Product highlight
        events.append(AnyTimelineEvent(ProductTimelineEvent(
            id: "product-20",
            videoTimestamp: 1200,
            productId: "408874",
            productName: "Paris Saint Germain Hjemmedrakt 2025/26",
            productImage: "https://...",
            price: "999.00",
            currency: "NOK",
            duration: 30,  // Show for 30 seconds
            metadata: nil
        )))
        
        // MARK: - Admin Comments (comentarios importantes)
        
        // 10' - Admin tactical note
        events.append(AnyTimelineEvent(AdminCommentEvent(
            id: "admin-10",
            videoTimestamp: 600,
            adminName: "Magnus Drivenes",
            comment: "Barcelona kontrollerer ballen godt. PSG venter på sin sjanse.",
            isPinned: false,
            metadata: nil
        )))
        
        // 13'15" - Admin comment sobre el gol
        events.append(AnyTimelineEvent(AdminCommentEvent(
            id: "admin-13",
            videoTimestamp: 795,
            adminName: "Magnus Drivenes",
            comment: "Nydelig mål! Dette er Champions League på sitt beste!",
            isPinned: true,
            metadata: nil
        )))
        
        // 32'15" - Admin comment sobre segundo gol
        events.append(AnyTimelineEvent(AdminCommentEvent(
            id: "admin-32",
            videoTimestamp: 1935,
            adminName: "Magnus Drivenes",
            comment: "Mbeumo dobler ledelsen! Fantastisk lagarbeid!",
            isPinned: true,
            metadata: nil
        )))
        
        // MARK: - Statistics Updates
        
        // 15' - Stats update
        events.append(AnyTimelineEvent(StatisticsUpdateEvent(
            id: "stats-15",
            videoTimestamp: 900,
            statName: "Ball i besittelse",
            homeValue: 58.5,
            awayValue: 41.5,
            metadata: nil
        )))
        
        // 30' - Stats update
        events.append(AnyTimelineEvent(StatisticsUpdateEvent(
            id: "stats-30",
            videoTimestamp: 1800,
            statName: "Skudd på mål",
            homeValue: 5,
            awayValue: 2,
            metadata: nil
        )))
        
        return events.sorted { $0.videoTimestamp < $1.videoTimestamp }
    }
    
    /// Generate timeline for Real Madrid - Barcelona (El Clásico)
    /// Target match for backend integration - mock data for now
    static func generateRealMadridBarcelonaTimeline() -> [AnyTimelineEvent] {
        var events: [AnyTimelineEvent] = []
        
        // Pre-Match
        events.append(AnyTimelineEvent(AnnouncementEvent(
            id: "lineup-madrid",
            videoTimestamp: -300,
            title: "Alineación Real Madrid",
            message: "Once inicial del Real Madrid",
            imageUrl: nil, actionUrl: nil, actionText: nil,
            metadata: ["type": "lineup", "team": "home", "formation": "4-3-3"]
        )))
        events.append(AnyTimelineEvent(AnnouncementEvent(
            id: "lineup-barcelona",
            videoTimestamp: -180,
            title: "Alineación Barcelona",
            message: "Once inicial del Barcelona",
            imageUrl: nil, actionUrl: nil, actionText: nil,
            metadata: ["type": "lineup", "team": "away", "formation": "4-3-3"]
        )))
        events.append(AnyTimelineEvent(AnnouncementEvent(
            id: "match-preview",
            videoTimestamp: -60,
            title: "¡El Clásico!",
            message: "Real Madrid vs Barcelona - La Liga",
            imageUrl: nil, actionUrl: nil, actionText: nil,
            metadata: ["type": "preview"]
        )))
        
        // Match Events
        events.append(AnyTimelineEvent(AnnouncementEvent(
            id: "kickoff",
            videoTimestamp: 0,
            title: "⚽ Saque inicial",
            message: "¡Comienza el Clásico! Real Madrid vs Barcelona",
            imageUrl: nil, actionUrl: nil, actionText: nil,
            metadata: ["type": "kickoff"]
        )))
        events.append(AnyTimelineEvent(MatchGoalEvent(
            id: "goal-12",
            videoTimestamp: 720,
            player: "V. Vinícius Jr.",
            team: .home,
            score: "1-0",
            assistBy: "J. Bellingham",
            isOwnGoal: false,
            isPenalty: false,
            metadata: nil
        )))
        events.append(AnyTimelineEvent(MatchGoalEvent(
            id: "goal-28",
            videoTimestamp: 1680,
            player: "Lamine Yamal",
            team: .away,
            score: "1-1",
            assistBy: "Pedri",
            isOwnGoal: false,
            isPenalty: false,
            metadata: nil
        )))
        events.append(AnyTimelineEvent(MatchCardEvent(
            id: "card-35",
            videoTimestamp: 2100,
            player: "A. Tchouaméni",
            team: .home,
            cardType: .yellow,
            reason: "Falta dura",
            metadata: nil
        )))
        events.append(AnyTimelineEvent(AnnouncementEvent(
            id: "halftime",
            videoTimestamp: 2700,
            title: "Descanso",
            message: "Fin del primer tiempo - Real Madrid 1-1 Barcelona",
            imageUrl: nil, actionUrl: nil, actionText: nil,
            metadata: ["type": "halftime"]
        )))
        
        // Casting events (halftime)
        events.append(AnyTimelineEvent(CastingContestEvent(
            id: "casting-contest-elclasico",
            videoTimestamp: 2720,
            title: "Concurso El Clásico",
            description: "Participa y gana premios exclusivos",
            prize: "1.000€ en productos",
            contestType: .quiz,
            metadata: ["imageAsset": "contest_prize_giftcard"],
            broadcastContext: nil
        )))
        events.append(AnyTimelineEvent(ChatMessageEvent(
            videoTimestamp: 2725,
            username: "Madridista",
            text: "¡Qué partido! El Clásico nunca decepciona 🔥",
            usernameColor: .orange,
            likes: 42
        )))
        events.append(AnyTimelineEvent(ChatMessageEvent(
            videoTimestamp: 2735,
            username: "Culé",
            text: "Lamine Yamal el futuro de La Liga 🏆",
            usernameColor: .orange,
            likes: 28
        )))
        
        // Second half
        events.append(AnyTimelineEvent(MatchGoalEvent(
            id: "goal-67",
            videoTimestamp: 4020,
            player: "Rodrygo",
            team: .home,
            score: "2-1",
            assistBy: "V. Vinícius Jr.",
            isOwnGoal: false,
            isPenalty: false,
            metadata: nil
        )))
        events.append(AnyTimelineEvent(MatchSubstitutionEvent(
            id: "sub-75",
            videoTimestamp: 4500,
            playerIn: "Raphinha",
            playerOut: "Lamine Yamal",
            team: .away,
            metadata: nil
        )))
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-80",
            videoTimestamp: 4800,
            minute: 80,
            text: "Minuto 80. El Real Madrid defiende el resultado. El Barcelona presiona buscando el empate.",
            commentaryType: .general,
            isHighlighted: false,
            metadata: nil
        )))
        
        return events.sorted { $0.videoTimestamp < $1.videoTimestamp }
    }
    
    /// Generate random chat messages throughout the match
    static func generateRandomChatMessages(count: Int = 50, maxMinute: Int = 90) -> [ChatMessageEvent] {
        let users: [(String, Color)] = [
            ("SportsFan23", .cyan),
            ("MatchMaster", .orange),
            ("TeamCaptain", .red),
            ("FutbolLoco", .yellow),
            ("DefenderPro", .blue),
            ("StrikerKing", .pink),
            ("CoachView", .indigo),
            ("TacticsGuru", .teal)
        ]
        
        let messages = [
            "Hvilket mål! 🔥",
            "For en redning!",
            "UTROLIG SPILL!!!",
            "Forsvaret sover...",
            "KOM IGJEN! 💪",
            "Nydelig pasning",
            "Keeperen er på et annet nivå",
            "SKYT!",
            "Perfekt posisjonering",
            "Denne kampen er gal",
            "Vi trenger mål nå",
            "Beste kampen denne sesongen",
            "FOR EN PASNING!",
            "Utrolig ballkontroll",
            "Perfekt timing",
            "Dette blir episk",
            "KJØR PÅ!!!",
            "Hvilken spilling!",
            "Fantastisk lagspill",
            "Publikum er tent 🔥"
        ]
        
        var chatEvents: [ChatMessageEvent] = []
        
        for i in 0..<count {
            let user = users.randomElement()!
            let text = messages.randomElement()!
            let minute = Int.random(in: 0...maxMinute)
            let seconds = TimeInterval(minute * 60 + Int.random(in: 0...59))
            
            let event = ChatMessageEvent(
                id: "chat-\(i)",
                videoTimestamp: seconds,
                username: user.0,
                text: text,
                usernameColor: user.1,
                likes: Int.random(in: 0...15)
            )
            
            chatEvents.append(event)
        }
        
        return chatEvents.sorted { $0.videoTimestamp < $1.videoTimestamp }
    }
}
