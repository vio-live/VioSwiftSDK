//
//  BarcelonaPSGTimelineData.swift
//  Viaplay
//
//  Rich timeline data for Barcelona vs PSG match
//  Detailed play-by-play commentary with all event types
//

import Foundation
import SwiftUI

extension TimelineDataGenerator {
    
    /// Generate rich Barcelona vs PSG timeline with detailed commentary
    static func generateBarcelonaPSGRichTimeline() -> [AnyTimelineEvent] {
        var events: [AnyTimelineEvent] = []
        
        // MARK: - PRE-PARTIDO (-15' to 0')
        
        // -15' - Velkommen
        events.append(AnyTimelineEvent(AnnouncementEvent(
            id: "pre-welcome",
            videoTimestamp: -900,
            title: "Velkommen!",
            message: "Barcelona mot PSG starter om 15 minutter. Gjør deg klar for en fantastisk kamp!",
            imageUrl: nil,
            actionUrl: nil,
            actionText: nil,
            metadata: ["type": "pre-match"]
        )))
        
        // -12' - Barcelona Lineup
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "pre-lineup-home-announce",
            videoTimestamp: -722,
            minute: -12,
            text: "Vi har nå Barcelona sitt startoppstilling!",
            commentaryType: .general,
            isHighlighted: false,
            metadata: nil
        )))
        
        events.append(AnyTimelineEvent(AnnouncementEvent(
            id: "pre-lineup-home",
            videoTimestamp: -720,
            title: "Oppstilling Barcelona",
            message: "4-3-3 formasjon",
            imageUrl: nil,
            actionUrl: nil,
            actionText: nil,
            metadata: [
                "type": "lineup",
                "team": "home",
                "formation": "4-3-3",
                "players": "Ter Stegen,Koundé,Araújo,Christensen,Alba,Busquets,De Jong,Pedri,Dembélé,Lewandowski,Ferran"
            ]
        )))
        
        // -11'30" - Poll about Barcelona lineup
        events.append(AnyTimelineEvent(PollTimelineEvent(
            id: "pre-poll-lineup-home",
            videoTimestamp: -690,
            question: "Liker du Barcelona sitt startoppstilling?",
            options: [
                .init(id: "yes", text: "Ja, bra 11!", voteCount: 0, percentage: nil),
                .init(id: "no", text: "Nei, ikke bra", voteCount: 0, percentage: nil),
                .init(id: "ok", text: "Ikke så verst", voteCount: 0, percentage: nil)
            ],
            duration: nil,
            endTimestamp: 0,
            metadata: ["type": "lineup-opinion"],
            broadcastContext: nil
        )))
        
        // -11' - PSG Lineup
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "pre-lineup-away-announce",
            videoTimestamp: -662,
            minute: -11,
            text: "Og nå har vi PSG sitt startoppstilling!",
            commentaryType: .general,
            isHighlighted: false,
            metadata: nil
        )))
        
        events.append(AnyTimelineEvent(AnnouncementEvent(
            id: "pre-lineup-away",
            videoTimestamp: -660,
            title: "Oppstilling PSG",
            message: "4-4-2 formasjon",
            imageUrl: nil,
            actionUrl: nil,
            actionText: nil,
            metadata: [
                "type": "lineup",
                "team": "away",
                "formation": "4-4-2",
                "players": "Donnarumma,Hakimi,Marquinhos,Ramos,Mendes,Vitinha,Verratti,Ruiz,Zaire-Emery,Mbappé,Kolo Muani"
            ]
        )))
        
        // -10'30" - Poll about PSG lineup
        events.append(AnyTimelineEvent(PollTimelineEvent(
            id: "pre-poll-lineup-away",
            videoTimestamp: -630,
            question: "Liker du PSG sitt startoppstilling?",
            options: [
                .init(id: "yes", text: "Ja, bra 11!", voteCount: 0, percentage: nil),
                .init(id: "no", text: "Nei, ikke bra", voteCount: 0, percentage: nil),
                .init(id: "ok", text: "Ikke så verst", voteCount: 0, percentage: nil)
            ],
            duration: nil,
            endTimestamp: 0,
            metadata: ["type": "lineup-opinion"],
            broadcastContext: nil
        )))
        
        // -8' - Player Interview
        events.append(AnyTimelineEvent(AnnouncementEvent(
            id: "pre-interview",
            videoTimestamp: -480,
            title: "Spillerintervju: Lamine Yamal",
            message: "Vi er klare. Dette blir en stor kamp for oss. Vi skal gi alt for fansene.",
            imageUrl: nil,
            actionUrl: nil,
            actionText: nil,
            metadata: [
                "type": "interview",
                "player": "Lamine Yamal",
                "team": "Barcelona"
            ]
        )))
        
        // -10' - Prediction Poll
        events.append(AnyTimelineEvent(PollTimelineEvent(
            id: "pre-poll-prediction",
            videoTimestamp: -600,
            question: "Spå resultatet av kampen",
            options: [
                .init(id: "home", text: "Barcelona vinner", voteCount: 0, percentage: nil),
                .init(id: "draw", text: "Uavgjort", voteCount: 0, percentage: nil),
                .init(id: "away", text: "PSG vinner", voteCount: 0, percentage: nil)
            ],
            duration: nil,
            endTimestamp: 0,
            metadata: ["type": "prediction"],
            broadcastContext: nil
        )))
        
        // -8' - Player Interview (Lamine Yamal)
        // Will be rendered as PlayerInterviewCard
        
        // -5' - H2H Stats
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "pre-h2h",
            videoTimestamp: -300,
            minute: -5,
            text: "Siste 5 kamper mellom lagene: Barcelona 3 seire, PSG 2 seire. Dette blir jevnt!",
            commentaryType: .general,
            isHighlighted: false,
            metadata: ["type": "pre-match"]
        )))
        
        // -2' - Countdown
        events.append(AnyTimelineEvent(AnnouncementEvent(
            id: "pre-countdown",
            videoTimestamp: -120,
            title: "Kampen starter snart!",
            message: "Bare 2 minutter til avspark. Spillerne går på banen nå.",
            imageUrl: nil,
            actionUrl: nil,
            actionText: nil,
            metadata: ["type": "pre-match"]
        )))
        
        // MARK: - KAMPEN (0' to 90') - Keep all existing events
        
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-pre-0",
            videoTimestamp: 5,
            minute: 0,
            text: "Velkommen til Camp Nou for denne spennende Champions League-kampen mellom Barcelona og PSG!",
            commentaryType: .general,
            isHighlighted: false,
            metadata: nil
        )))
        
        // MARK: - 1' - Kickoff
        
        events.append(AnyTimelineEvent(AnnouncementEvent(
            id: "kickoff",
            videoTimestamp: 60,
            title: "Avspark",
            message: "Kampen starter! Barcelona mot PSG",
            imageUrl: nil,
            actionUrl: nil,
            actionText: nil,
            metadata: ["type": "kickoff", "phase": "kickoff"]
        )))
        
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-1-start",
            videoTimestamp: 62,
            minute: 1,
            text: "Barcelona starter kampen. Første berøring for laget.",
            commentaryType: .kickoff,
            isHighlighted: false,
            metadata: nil
        )))
        
        // MARK: - Early Minutes (1'-10')
        
        // 2' - Early play
        events.append(AnyTimelineEvent(ChatMessageEvent(
            videoTimestamp: 120,
            username: "SportsFan23",
            text: "La oss gå Barcelona! 💪",
            usernameColor: .cyan
        )))
        
        // 2' - Luka Modrić tweet
        events.append(AnyTimelineEvent(TweetEvent(
            id: "tweet-2",
            videoTimestamp: 125,
            authorName: "Luka Modrić",
            authorHandle: "@LukaModric10",
            authorAvatar: "https://pbs.twimg.com/profile_images/1467838580013015046/Ri-Mx4k0_400x400.jpg",
            tweetText: "Nikada ne odustaj! ⚽🔥 #ChampionsLeague",
            isVerified: true,
            likes: 1345,
            retweets: 878,
            metadata: nil
        )))
        
        // 3' - Chance
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-3",
            videoTimestamp: 180,
            minute: 3,
            text: "Fermín (Barcelona) prøver å sende ballen forbi forsvaret, men en forsvarer klipper ballen.",
            commentaryType: .chance,
            isHighlighted: false,
            metadata: nil
        )))
        
        // 5' - Substitution
        events.append(AnyTimelineEvent(MatchSubstitutionEvent(
            id: "sub-5",
            videoTimestamp: 300,
            playerIn: "A. Scott",
            playerOut: "T. Adams",
            team: .away,
            metadata: nil
        )))
        
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-5-sub",
            videoTimestamp: 302,
            minute: 5,
            text: "Tidlig bytte! PSG tar av T. Adams og sender inn A. Scott.",
            commentaryType: .substitution,
            isHighlighted: false,
            metadata: nil
        )))
        
        events.append(AnyTimelineEvent(ChatMessageEvent(
            videoTimestamp: 310,
            username: "TacticsGuru",
            text: "Interessant bytte så tidlig 🤔",
            usernameColor: .teal
        )))
        
        // 6' - Chance
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-6",
            videoTimestamp: 360,
            minute: 6,
            text: "Jules Kounde (Barcelona) sender ballen inn i feltet, men en forsvarer er våken og klarerer.",
            commentaryType: .chance,
            isHighlighted: false,
            metadata: nil
        )))
        
        // 7' - Contest
        events.append(AnyTimelineEvent(AnnouncementEvent(
            id: "contest-7",
            videoTimestamp: 420,
            title: "Vinn en drakt fra ditt favorittlag!",
            message: "Delta i konkurransen og få sjansen til å vinne en signert drakt fra XXL Sports.",
            imageUrl: nil,
            actionUrl: nil,
            actionText: "Delta",
            metadata: ["type": "contest", "prize": "Fotballdrakt"]
        )))
        
        // 8' - Erling Haaland tweet
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
        
        // 8' - Foul
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-8-foul",
            videoTimestamp: 485,
            minute: 8,
            text: "Falta! Eduardo Camavinga (PSG) takler hardt og dommeren blåser.",
            commentaryType: .foul,
            isHighlighted: false,
            metadata: nil
        )))
        
        // 10' - Admin comment
        events.append(AnyTimelineEvent(AdminCommentEvent(
            id: "admin-10",
            videoTimestamp: 600,
            adminName: "Magnus Drivenes",
            comment: "Barcelona kontrollerer ballen godt. PSG venter på sin sjanse.",
            isPinned: false,
            metadata: nil
        )))
        
        // 10' - Poll
        events.append(AnyTimelineEvent(PollTimelineEvent(
            id: "poll-10",
            videoTimestamp: 605,
            question: "Hvem vinner denne kampen?",
            options: [
                .init(id: "opt1", text: "Barcelona", voteCount: 3456, percentage: 65),
                .init(id: "opt2", text: "PSG", voteCount: 1234, percentage: 23),
                .init(id: "opt3", text: "Uavgjort", voteCount: 645, percentage: 12)
            ],
            duration: 600,
            endTimestamp: 1200,
            metadata: nil,
            broadcastContext: nil
        )))
        
        // 11' - Chance
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-11",
            videoTimestamp: 660,
            minute: 11,
            text: "Alejandro Balde (Barcelona) prøver å nå en lang ball, men den er for lang og går ut.",
            commentaryType: .chance,
            isHighlighted: false,
            metadata: nil
        )))
        
        // MARK: - 13' - FIRST GOAL
        
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
        
        // Highlight video del gol
        events.append(AnyTimelineEvent(HighlightTimelineEvent(
            id: "highlight-goal-13",
            videoTimestamp: 780,
            title: "MÅL: A. Diallo",
            description: "Nydelig avslutning fra Diallo etter assist fra Bruno!",
            thumbnailUrl: nil,
            clipUrl: "https://firebasestorage.googleapis.com/v0/b/tipio-1ec97.appspot.com/o/1.MP4?alt=media&token=898b7836-5e27-492d-82bb-9d7bb50f9d66",
            highlightType: .goal,
            metadata: ["score": "1-0", "player": "A. Diallo"]
        )))
        
        // 13'03" - Goal Replay (3 seconds after)
        events.append(AnyTimelineEvent(HighlightTimelineEvent(
            id: "replay-goal-13",
            videoTimestamp: 783,
            title: "Her er målet: A. Diallo!",
            description: "Se reprisen av Barcelona sitt første mål",
            thumbnailUrl: nil,
            clipUrl: "https://firebasestorage.googleapis.com/v0/b/tipio-1ec97.appspot.com/o/1.MP4?alt=media&token=898b7836-5e27-492d-82bb-9d7bb50f9d66",
            highlightType: .goal,
            metadata: ["replay": "true", "originalGoal": "goal-13"]
        )))
        
        // 13'05" - Celebration chats
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
        
        // 13'15" - Admin celebration
        events.append(AnyTimelineEvent(AdminCommentEvent(
            id: "admin-13",
            videoTimestamp: 795,
            adminName: "Magnus Drivenes",
            comment: "Nydelig mål! Dette er Champions League på sitt beste!",
            isPinned: true,
            metadata: nil
        )))
        
        // 13'30" - Mbappé tweet
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
        
        // MARK: - 15'-25' - Mid First Half
        
        // 15' - Stats update
        events.append(AnyTimelineEvent(StatisticsUpdateEvent(
            id: "stats-15",
            videoTimestamp: 900,
            statName: "Ball i besittelse",
            homeValue: 58.5,
            awayValue: 41.5,
            metadata: nil
        )))
        
        // 18' - YELLOW CARD
        events.append(AnyTimelineEvent(MatchCardEvent(
            id: "card-18",
            videoTimestamp: 1080,
            player: "Casemiro",
            team: .home,
            cardType: .yellow,
            reason: "Falta táctica",
            metadata: nil
        )))
        
        // Highlight video de la tarjeta
        events.append(AnyTimelineEvent(HighlightTimelineEvent(
            id: "highlight-card-18",
            videoTimestamp: 1080,
            title: "Gult kort: Casemiro",
            description: "Falta táctica fra Casemiro",
            thumbnailUrl: nil,
            clipUrl: "https://firebasestorage.googleapis.com/v0/b/tipio-1ec97.appspot.com/o/3.MP4?alt=media&token=f28dadf8-05df-4544-a21f-a4c45836793f",
            highlightType: .yellowCard,
            metadata: ["player": "Casemiro"]
        )))
        
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-18",
            videoTimestamp: 1082,
            minute: 18,
            text: "Gult kort til Casemiro (Barcelona) for en taktisk falta.",
            commentaryType: .card,
            isHighlighted: false,
            metadata: nil
        )))
        
        // 20' - Cristiano Ronaldo tweet
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
        
        // 20' - Poll
        events.append(AnyTimelineEvent(PollTimelineEvent(
            id: "poll-20",
            videoTimestamp: 1205,
            question: "Hvem scorer neste mål?",
            options: [
                .init(id: "opt1", text: "Barcelona", voteCount: 2890, percentage: 58),
                .init(id: "opt2", text: "PSG", voteCount: 1567, percentage: 31),
                .init(id: "opt3", text: "Ingen flere mål", voteCount: 543, percentage: 11)
            ],
            duration: 900,
            endTimestamp: 2100,
            metadata: nil,
            broadcastContext: nil
        )))
        
        // 22' - Corner
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-22",
            videoTimestamp: 1320,
            minute: 22,
            text: "Corner for Barcelona. Raphinha tar corneren...",
            commentaryType: .corner,
            isHighlighted: false,
            metadata: nil
        )))
        
        // 25' - YELLOW CARD
        events.append(AnyTimelineEvent(MatchCardEvent(
            id: "card-25",
            videoTimestamp: 1500,
            player: "M. Tavernier",
            team: .away,
            cardType: .yellow,
            reason: nil,
            metadata: nil
        )))
        
        // Highlight video de gran ocasión
        events.append(AnyTimelineEvent(HighlightTimelineEvent(
            id: "highlight-chance-25",
            videoTimestamp: 1500,
            title: "Stor sjanse!",
            description: "Nesten 2-0 for Barcelona!",
            thumbnailUrl: nil,
            clipUrl: "https://firebasestorage.googleapis.com/v0/b/tipio-1ec97.appspot.com/o/2.MP4?alt=media&token=9011a94a-1085-4b69-bd41-3b1432ca577a",
            highlightType: .chance,
            metadata: nil
        )))
        
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-25",
            videoTimestamp: 1502,
            minute: 25,
            text: "Gult kort til M. Tavernier (PSG).",
            commentaryType: .card,
            isHighlighted: false,
            metadata: nil
        )))
        
        // 28' - Save
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-28",
            videoTimestamp: 1680,
            minute: 28,
            text: "Stor redning! Keeperen til PSG kaster seg og redder et hardt skudd fra Pedri.",
            commentaryType: .save,
            isHighlighted: false,
            metadata: nil
        )))
        
        // MARK: - 30'-45' - End of First Half
        
        // 30' - Stats
        events.append(AnyTimelineEvent(StatisticsUpdateEvent(
            id: "stats-30",
            videoTimestamp: 1800,
            statName: "Skudd på mål",
            homeValue: 5,
            awayValue: 2,
            metadata: nil
        )))
        
        // 32' - SECOND GOAL
        events.append(AnyTimelineEvent(MatchGoalEvent(
            id: "goal-32",
            videoTimestamp: 1920,
            player: "B. Mbeumo",
            team: .home,
            score: "2-0",
            assistBy: "Diogo Dalot",
            isOwnGoal: false,
            isPenalty: false,
            metadata: nil
        )))
        
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-32-goal",
            videoTimestamp: 1922,
            minute: 32,
            text: "GOOOL! Mbeumo dobler ledelsen for Barcelona med en presis avslutning! 2-0!",
            commentaryType: .goal,
            isHighlighted: true,
            metadata: nil
        )))
        
        // 32'03" - Goal Replay
        events.append(AnyTimelineEvent(HighlightTimelineEvent(
            id: "replay-goal-32",
            videoTimestamp: 1923,
            title: "Her er målet: B. Mbeumo!",
            description: "Se reprisen av Barcelona sitt andre mål",
            thumbnailUrl: nil,
            clipUrl: "https://firebasestorage.googleapis.com/v0/b/tipio-1ec97.appspot.com/o/2.MP4?alt=media&token=9011a94a-1085-4b69-bd41-3b1432ca577a",
            highlightType: .goal,
            metadata: ["replay": "true"]
        )))
        
        // 32'10" - Celebration
        events.append(AnyTimelineEvent(ChatMessageEvent(
            videoTimestamp: 1930,
            username: "UltrasGroup",
            text: "ENDA ET MÅL!!! 🔥🔥",
            usernameColor: .red,
            likes: 67
        )))
        
        // 32'15" - Admin
        events.append(AnyTimelineEvent(AdminCommentEvent(
            id: "admin-32",
            videoTimestamp: 1935,
            adminName: "Magnus Drivenes",
            comment: "Mbeumo dobler ledelsen! Fantastisk lagarbeid!",
            isPinned: true,
            metadata: nil
        )))
        
        // 35' - Poll
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
        
        // 40' - Chance
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-40",
            videoTimestamp: 2400,
            minute: 40,
            text: "PSG prøver å komme seg tilbake. Mbappé med et farlig løp, men Barcelona-forsvaret står støtt.",
            commentaryType: .chance,
            isHighlighted: false,
            metadata: nil
        )))
        
        // 43' - Corner
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-43",
            videoTimestamp: 2580,
            minute: 43,
            text: "Corner for PSG. Kan de redusere før pause?",
            commentaryType: .corner,
            isHighlighted: false,
            metadata: nil
        )))
        
        // MARK: - 45' - HALFTIME
        
        events.append(AnyTimelineEvent(AnnouncementEvent(
            id: "halftime",
            videoTimestamp: 2700,
            title: "Pause",
            message: "Første omgang ferdig. Barcelona leder 2-0.",
            imageUrl: nil,
            actionUrl: nil,
            actionText: nil,
            metadata: ["type": "halftime", "phase": "halftime"]
        )))
        
        // Halftime contest
        events.append(AnyTimelineEvent(AnnouncementEvent(
            id: "halftime-contest",
            videoTimestamp: 2710,
            title: "Vinn drakten til ditt favorittlag!",
            message: "Svar på spørsmålet for å delta i trekningen",
            imageUrl: nil,
            actionUrl: nil,
            actionText: "Delta",
            metadata: [
                "type": "contest",
                "prize": "Fotballdrakt",
                "question": "Ville du reist til Champions League-finalen hvis laget ditt kvalifiserte seg?",
                "drawTime": "Etter kampen"
            ]
        )))
        
        // Halftime stats event
        events.append(AnyTimelineEvent(AnnouncementEvent(
            id: "halftime-stats",
            videoTimestamp: 2705,
            title: "Statistikk første omgang",
            message: "Se tallene fra første omgang",
            imageUrl: nil,
            actionUrl: nil,
            actionText: "Se statistikk",
            metadata: ["type": "halftime-stats", "phase": "halftime"]
        )))
        
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-45",
            videoTimestamp: 2702,
            minute: 45,
            text: "Pause! Barcelona går til garderoben med en komfortabel 2-0 ledelse.",
            commentaryType: .halftime,
            isHighlighted: false,
            metadata: nil
        )))
        
        // MARK: - 46' - SECOND HALF KICKOFF
        
        events.append(AnyTimelineEvent(AnnouncementEvent(
            id: "secondhalf",
            videoTimestamp: 2760,
            title: "Andre omgang",
            message: "Kampen gjenopptas!",
            imageUrl: nil,
            actionUrl: nil,
            actionText: nil,
            metadata: ["type": "kickoff", "phase": "secondhalf"]
        )))
        
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-46",
            videoTimestamp: 2762,
            minute: 46,
            text: "Andre omgang er i gang! PSG må score for å komme tilbake.",
            commentaryType: .kickoff,
            isHighlighted: false,
            metadata: nil
        )))
        
        // MARK: - Second Half Events
        
        // 47' - PSG GOAL
        events.append(AnyTimelineEvent(MatchGoalEvent(
            id: "goal-47",
            videoTimestamp: 2820,
            player: "J. Kluivert",
            team: .away,
            score: "2-1",
            assistBy: nil,
            isOwnGoal: false,
            isPenalty: false,
            metadata: nil
        )))
        
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-47-goal",
            videoTimestamp: 2822,
            minute: 47,
            text: "GOOOL for PSG! Kluivert reduserer til 2-1! Kampen er i gang igjen!",
            commentaryType: .goal,
            isHighlighted: true,
            metadata: nil
        )))
        
        // 47'03" - Goal Replay
        events.append(AnyTimelineEvent(HighlightTimelineEvent(
            id: "replay-goal-47",
            videoTimestamp: 2823,
            title: "Her er målet: J. Kluivert!",
            description: "Se reprisen av PSG sitt mål",
            thumbnailUrl: nil,
            clipUrl: "https://firebasestorage.googleapis.com/v0/b/tipio-1ec97.appspot.com/o/3.MP4?alt=media&token=f28dadf8-05df-4544-a21f-a4c45836793f",
            highlightType: .goal,
            metadata: ["replay": "true"]
        )))
        
        events.append(AnyTimelineEvent(ChatMessageEvent(
            videoTimestamp: 2825,
            username: "PSGFan",
            text: "Comeback time! 🔥",
            usernameColor: .blue,
            likes: 38
        )))
        
        // 50' - Chance
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-50",
            videoTimestamp: 3000,
            minute: 50,
            text: "Barcelona prøver å svare raskt. Fermín med et skudd som går like utenfor.",
            commentaryType: .chance,
            isHighlighted: false,
            metadata: nil
        )))
        
        // 55' - Foul
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-55",
            videoTimestamp: 3300,
            minute: 55,
            text: "Frispark til PSG etter falta på Marquinhos.",
            commentaryType: .foul,
            isHighlighted: false,
            metadata: nil
        )))
        
        // 58' - Substitution
        events.append(AnyTimelineEvent(MatchSubstitutionEvent(
            id: "sub-58",
            videoTimestamp: 3480,
            playerIn: "Bruno Fernandes",
            playerOut: "A. Diallo",
            team: .home,
            metadata: nil
        )))
        
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-58",
            videoTimestamp: 3482,
            minute: 58,
            text: "Barcelona bytter: Bruno Fernandes inn for Diallo.",
            commentaryType: .substitution,
            isHighlighted: false,
            metadata: nil
        )))
        
        // 62' - Corner
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-62",
            videoTimestamp: 3720,
            minute: 62,
            text: "Corner for PSG. Viktig mulighet her...",
            commentaryType: .corner,
            isHighlighted: false,
            metadata: nil
        )))
        
        // 65' - YELLOW CARD
        events.append(AnyTimelineEvent(MatchCardEvent(
            id: "card-65",
            videoTimestamp: 3900,
            player: "Álex Jiménez",
            team: .away,
            cardType: .yellow,
            reason: nil,
            metadata: nil
        )))
        
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-65",
            videoTimestamp: 3902,
            minute: 65,
            text: "Álex Jiménez (PSG) får gult kort.",
            commentaryType: .card,
            isHighlighted: false,
            metadata: nil
        )))
        
        // 68' - Save
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-68",
            videoTimestamp: 4080,
            minute: 68,
            text: "Fantastisk redning! Ter Stegen kaster seg og redder PSG sitt skudd.",
            commentaryType: .save,
            isHighlighted: false,
            metadata: nil
        )))
        
        // MARK: - 72' - THIRD GOAL
        
        events.append(AnyTimelineEvent(MatchGoalEvent(
            id: "goal-72",
            videoTimestamp: 4320,
            player: "Matheus Cunha",
            team: .home,
            score: "3-1",
            assistBy: nil,
            isOwnGoal: false,
            isPenalty: false,
            metadata: nil
        )))
        
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-72-goal",
            videoTimestamp: 4322,
            minute: 72,
            text: "GOOOL! Matheus Cunha avgjør kampen! Barcelona leder 3-1!",
            commentaryType: .goal,
            isHighlighted: true,
            metadata: nil
        )))
        
        // 72'03" - Goal Replay
        events.append(AnyTimelineEvent(HighlightTimelineEvent(
            id: "replay-goal-72",
            videoTimestamp: 4323,
            title: "Her er målet: Matheus Cunha!",
            description: "Se reprisen av Barcelona sitt tredje mål",
            thumbnailUrl: nil,
            clipUrl: "https://firebasestorage.googleapis.com/v0/b/tipio-1ec97.appspot.com/o/1.MP4?alt=media&token=898b7836-5e27-492d-82bb-9d7bb50f9d66",
            highlightType: .goal,
            metadata: ["replay": "true"]
        )))
        
        events.append(AnyTimelineEvent(ChatMessageEvent(
            videoTimestamp: 4325,
            username: "MatchMaster",
            text: "GAME OVER! 🎉",
            usernameColor: .orange,
            likes: 54
        )))
        
        // 75' - Chance
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-75",
            videoTimestamp: 4500,
            minute: 75,
            text: "PSG presser for å redusere. Mbappé med et farlig forsøk.",
            commentaryType: .chance,
            isHighlighted: false,
            metadata: nil
        )))
        
        // 78' - Substitution
        events.append(AnyTimelineEvent(MatchSubstitutionEvent(
            id: "sub-78",
            videoTimestamp: 4680,
            playerIn: "M. Mount",
            playerOut: "B. Mbeumo",
            team: .home,
            metadata: nil
        )))
        
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-78",
            videoTimestamp: 4682,
            minute: 78,
            text: "Bytte for Barcelona: Mount inn for målscorer Mbeumo.",
            commentaryType: .substitution,
            isHighlighted: false,
            metadata: nil
        )))
        
        // 82' - Foul
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-82",
            videoTimestamp: 4920,
            minute: 82,
            text: "Frispark i farlig posisjon for PSG etter falta på utsiden av feltet.",
            commentaryType: .foul,
            isHighlighted: false,
            metadata: nil
        )))
        
        // 85' - RED CARD
        events.append(AnyTimelineEvent(MatchCardEvent(
            id: "card-85",
            videoTimestamp: 5100,
            player: "T. Adams",
            team: .away,
            cardType: .red,
            reason: "Brutalt tackle",
            metadata: nil
        )))
        
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-85-red",
            videoTimestamp: 5102,
            minute: 85,
            text: "RØDT KORT! T. Adams blir utvist etter et brutalt tackle!",
            commentaryType: .card,
            isHighlighted: true,
            metadata: nil
        )))
        
        events.append(AnyTimelineEvent(ChatMessageEvent(
            videoTimestamp: 5105,
            username: "RefWatch",
            text: "Fortjent rødt! 🟥",
            usernameColor: .red,
            likes: 42
        )))
        
        // 88' - Corner
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-88",
            videoTimestamp: 5280,
            minute: 88,
            text: "Barcelona med corner. De prøver å score det fjerde målet.",
            commentaryType: .corner,
            isHighlighted: false,
            metadata: nil
        )))
        
        // MARK: - 90' - FULLTIME
        
        events.append(AnyTimelineEvent(AnnouncementEvent(
            id: "fulltime",
            videoTimestamp: 5400,
            title: "Fulltid",
            message: "Kampen er over! Barcelona 3-1 PSG",
            imageUrl: nil,
            actionUrl: nil,
            actionText: nil,
            metadata: ["type": "fulltime", "phase": "fulltime"]
        )))
        
        events.append(AnyTimelineEvent(CommentaryEvent(
            id: "comm-90",
            videoTimestamp: 5402,
            minute: 90,
            text: "FULLTID! Barcelona vinner 3-1 og tar et stort steg mot kvartfinalen!",
            commentaryType: .halftime,
            isHighlighted: true,
            metadata: nil
        )))
        
        // MARK: - POST-PARTIDO (90'+ to 105')
        
        // 91' - Final Stats (will be rendered as FinalStatsCard)
        events.append(AnyTimelineEvent(AnnouncementEvent(
            id: "post-final-stats",
            videoTimestamp: 5460,
            title: "Sluttstatistikk",
            message: "Se alle tallene fra kampen",
            imageUrl: nil,
            actionUrl: nil,
            actionText: nil,
            metadata: ["type": "final-stats"]
        )))
        
        // 92' - Poll Results
        events.append(AnyTimelineEvent(AnnouncementEvent(
            id: "post-poll-results",
            videoTimestamp: 5520,
            title: "Avstemningsresultater",
            message: "Se hvordan andre stemte!",
            imageUrl: nil,
            actionUrl: nil,
            actionText: nil,
            metadata: ["type": "poll-results"]
        )))
        
        // 93' - MOTM Voting (will be rendered as MOTMVotingCard)
        // Handled separately as component
        
        // 95' - Highlights Summary
        events.append(AnyTimelineEvent(AnnouncementEvent(
            id: "post-highlights",
            videoTimestamp: 5700,
            title: "Høydepunkter",
            message: "Se alle de beste øyeblikkene fra kampen",
            imageUrl: nil,
            actionUrl: nil,
            actionText: "Se høydepunkter",
            metadata: ["type": "highlights-summary"]
        )))
        
        // 96' - Contest Winner Announcement
        events.append(AnyTimelineEvent(AnnouncementEvent(
            id: "post-contest-winner",
            videoTimestamp: 5760,
            title: "Vinner av konkurransen!",
            message: "Gratulerer til Ole Hansen som vant fotballdrakten!",
            imageUrl: nil,
            actionUrl: nil,
            actionText: nil,
            metadata: ["type": "contest-winner", "winner": "Ole Hansen"]
        )))
        
        // 96'10" - User did not win message
        events.append(AnyTimelineEvent(AnnouncementEvent(
            id: "post-contest-user-loss",
            videoTimestamp: 5770,
            title: "Denne gangen ble det ikke deg",
            message: "Dessverre vant du ikke denne gangen, men fortsett å delta i våre konkurranser de neste kampene!",
            imageUrl: nil,
            actionUrl: nil,
            actionText: "Se neste konkurranse",
            metadata: ["type": "contest-user-result", "won": "false"]
        )))
        
        // 98' - Thank You
        events.append(AnyTimelineEvent(AnnouncementEvent(
            id: "post-thanks",
            videoTimestamp: 5880,
            title: "Takk for at du så på!",
            message: "Neste kamp: Real Madrid vs Manchester City i morgen kl 21:00",
            imageUrl: nil,
            actionUrl: nil,
            actionText: "Se kampoversikt",
            metadata: ["type": "end-message"]
        )))
        
        // Add random chat messages throughout (full 120 minutes)
        let randomChats = TimelineDataGenerator.generateRandomChatMessages(count: 50, maxMinute: 105)
        print("💬 [BarcelonaPSG] Generated \(randomChats.count) random chat messages")
        for chat in randomChats {
            events.append(AnyTimelineEvent(chat))
        }
        
        print("🎬 [BarcelonaPSG] Total events before sort: \(events.count)")
        let sorted = events.sorted { $0.videoTimestamp < $1.videoTimestamp }
        print("🎬 [BarcelonaPSG] Returning \(sorted.count) sorted events")
        
        // Show first 30 events with timestamps
        print("🎬 [BarcelonaPSG] First 30 events:")
        for (index, event) in sorted.prefix(30).enumerated() {
            let minute = Int(event.videoTimestamp / 60)
            print("  \(index+1). \(event.eventType.rawValue) at \(event.videoTimestamp)s (\(minute)')")
        }
        
        // Count by type for debugging
        let tweets = sorted.filter { $0.eventType == .tweet }.count
        let chats = sorted.filter { $0.eventType == .chatMessage }.count
        let highlights = sorted.filter { $0.eventType == .highlight }.count
        let polls = sorted.filter { $0.eventType == .poll }.count
        
        print("🎬 [BarcelonaPSG] Tweets: \(tweets), Chats: \(chats), Highlights: \(highlights), Polls: \(polls)")
        
        return sorted
    }
}
