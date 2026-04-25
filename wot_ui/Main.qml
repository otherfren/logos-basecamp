import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    readonly property string selfPubkey: "0x1a2b...cd3e"

    // Sort state (table header controls this)
    property string sortCol: "name"
    property string sortDir: "asc"

    // Active tab (custom segmented control)
    property int currentTab: 0

    // Seeded/cached mutual-contact counts (mock until graph logic exists)
    property var _mutualCache: ({
        alice: 7, bob:  4, eve:    0, frank: 8, greg: 0,
        helen: 6, ivan: 1, jade:   0, mallory: 0,
        kate:  6, nina: 4, leo:    2, rose:  1, tom: 0
    })

    QtObject {
        id: theme
        readonly property color bg:            "#f0f0f0"
        readonly property color card:          "#fafafa"
        readonly property color cardBorder:    "#d4d4d4"
        readonly property color cardHover:     "#f4f4f4"
        readonly property color divider:       "#d4d4d4"
        readonly property color textPrimary:   "#1f1f1f"
        readonly property color textSecondary: "#555555"
        readonly property color textMuted:     "#8a8a8a"
        readonly property color accent:        "#8a6a3a"
        readonly property color accentDim:     "#b89773"
        readonly property color scoreStrong:   "#1a7f37"
        readonly property color scoreOk:       "#2da44e"
        readonly property color scoreCaution:  "#bf8700"
        readonly property color scoreFraud:    "#cf222e"
        readonly property color onBadge:       "#ffffff"
    }

    QtObject {
        id: cols
        readonly property int name:   100
        readonly property int mine:   100
        readonly property int theirs: 130
        readonly property int mutual: 140
    }

    Rectangle {
        anchors.fill: parent
        color: theme.bg
    }

    ListModel { id: ratings }
    ListModel { id: contactsModel }

    Component.onCompleted: {
        seedMockData()
        refreshContacts()
    }

    function seedMockData() {
        ratings.append({ rater: "self",    rated: "alice",   score:  3, context: "co-founded a company",           ts: "2026-01-15" })
        ratings.append({ rater: "alice",   rated: "self",    score:  3, context: "would trust with my life",       ts: "2026-01-15" })
        ratings.append({ rater: "self",    rated: "bob",     score:  1, context: "reliable OTC counterparty",      ts: "2026-02-03" })
        ratings.append({ rater: "bob",     rated: "self",    score:  1, context: "fair trades, always punctual",   ts: "2026-02-04" })
        ratings.append({ rater: "self",    rated: "frank",   score:  3, context: "mentor, brought me to Logos",    ts: "2025-11-22" })
        ratings.append({ rater: "frank",   rated: "self",    score:  3, context: "sharp builder, worth knowing",   ts: "2025-11-25" })
        ratings.append({ rater: "self",    rated: "helen",   score:  1, context: "ok OTC, small trades only",      ts: "2026-02-18" })
        ratings.append({ rater: "helen",   rated: "self",    score:  3, context: "most reliable trader in my net", ts: "2026-02-19" })
        ratings.append({ rater: "self",    rated: "greg",    score: -1, context: "flaky on delivery, twice",       ts: "2026-03-02" })
        ratings.append({ rater: "self",    rated: "eve",     score: -1, context: "chargeback dispute",             ts: "2026-04-01" })
        ratings.append({ rater: "eve",     rated: "self",    score: -3, context: "refused refund on bad item",     ts: "2026-04-02" })
        ratings.append({ rater: "self",    rated: "ivan",    score: -3, context: "sold me fake keycards",          ts: "2026-03-20" })
        ratings.append({ rater: "ivan",    rated: "self",    score: -1, context: "accused me of fraud publicly",   ts: "2026-03-22" })
        ratings.append({ rater: "jade",    rated: "self",    score:  1, context: "good OTC counterpart",           ts: "2026-04-10" })
        ratings.append({ rater: "self",    rated: "mallory", score: -3, context: "phishing attempt via chat",      ts: "2026-04-18" })

        // additional self-edges to widen the contact set
        ratings.append({ rater: "self",    rated: "kate",    score:  3, context: "team lead at logos-storage",     ts: "2025-12-01" })
        ratings.append({ rater: "kate",    rated: "self",    score:  3, context: "talented contributor",           ts: "2025-12-02" })
        ratings.append({ rater: "self",    rated: "nina",    score:  1, context: "fair OTC counterparty",          ts: "2026-03-15" })
        ratings.append({ rater: "nina",    rated: "self",    score:  1, context: "fair trades, on schedule",       ts: "2026-03-16" })
        ratings.append({ rater: "self",    rated: "leo",     score:  1, context: "occasional OTC partner",         ts: "2026-02-22" })
        ratings.append({ rater: "leo",     rated: "self",    score:  1, context: "honest counterparty",            ts: "2026-02-22" })
        ratings.append({ rater: "self",    rated: "rose",    score:  1, context: "small trades, ok",               ts: "2026-04-02" })
        ratings.append({ rater: "rose",    rated: "self",    score:  3, context: "fast settlement, recommended",   ts: "2026-04-03" })
        ratings.append({ rater: "tom",     rated: "self",    score: -1, context: "disputed an order",              ts: "2026-04-12" })

        // dense positive web among trusted peers (alice/bob/frank/helen/kate)
        ratings.append({ rater: "alice",   rated: "bob",     score:  1, context: "occasional OTC partner",         ts: "2026-02-10" })
        ratings.append({ rater: "alice",   rated: "frank",   score:  3, context: "long-time co-conspirator",       ts: "2025-09-12" })
        ratings.append({ rater: "alice",   rated: "helen",   score:  3, context: "trustworthy across markets",     ts: "2026-01-08" })
        ratings.append({ rater: "alice",   rated: "kate",    score:  3, context: "co-led storage rollout",         ts: "2025-12-04" })
        ratings.append({ rater: "bob",     rated: "alice",   score:  1, context: "fair trades",                    ts: "2026-02-11" })
        ratings.append({ rater: "bob",     rated: "frank",   score:  1, context: "professional",                   ts: "2026-01-22" })
        ratings.append({ rater: "bob",     rated: "helen",   score:  1, context: "helpful",                        ts: "2026-02-15" })
        ratings.append({ rater: "bob",     rated: "kate",    score:  1, context: "small but reliable trades",      ts: "2026-03-01" })
        ratings.append({ rater: "frank",   rated: "alice",   score:  3, context: "vouched for since 2018",         ts: "2025-09-13" })
        ratings.append({ rater: "frank",   rated: "bob",     score:  1, context: "honest broker",                  ts: "2026-01-25" })
        ratings.append({ rater: "frank",   rated: "helen",   score:  3, context: "decade-long colleague",          ts: "2025-10-02" })
        ratings.append({ rater: "frank",   rated: "kate",    score:  3, context: "great architect",                ts: "2025-12-05" })
        ratings.append({ rater: "helen",   rated: "alice",   score:  3, context: "always pays",                    ts: "2026-01-09" })
        ratings.append({ rater: "helen",   rated: "bob",     score:  1, context: "good for small lots",            ts: "2026-02-16" })
        ratings.append({ rater: "helen",   rated: "frank",   score:  1, context: "professional",                   ts: "2025-10-03" })
        ratings.append({ rater: "helen",   rated: "kate",    score:  3, context: "most consistent contributor",    ts: "2025-12-08" })
        ratings.append({ rater: "kate",    rated: "alice",   score:  3, context: "co-founder material",            ts: "2025-12-04" })
        ratings.append({ rater: "kate",    rated: "bob",     score:  1, context: "fair OTC for small amounts",     ts: "2026-03-02" })
        ratings.append({ rater: "kate",    rated: "frank",   score:  3, context: "mentor",                         ts: "2025-12-06" })
        ratings.append({ rater: "kate",    rated: "helen",   score:  3, context: "decade clean record",            ts: "2025-12-09" })

        // negative consensus on bad actors (eve, ivan, mallory)
        ratings.append({ rater: "alice",   rated: "eve",     score: -3, context: "stole my deposit",               ts: "2026-04-05" })
        ratings.append({ rater: "bob",     rated: "eve",     score: -1, context: "shady, would avoid",             ts: "2026-04-04" })
        ratings.append({ rater: "frank",   rated: "eve",     score: -3, context: "fraud confirmed by 3 sources",   ts: "2026-04-06" })
        ratings.append({ rater: "helen",   rated: "eve",     score: -3, context: "scammer",                        ts: "2026-04-07" })
        ratings.append({ rater: "kate",    rated: "eve",     score: -1, context: "unreliable",                     ts: "2026-04-08" })
        ratings.append({ rater: "nina",    rated: "eve",     score: -3, context: "scammed me last year",           ts: "2026-04-09" })

        ratings.append({ rater: "alice",   rated: "ivan",    score: -3, context: "fake keycards confirmed",        ts: "2026-03-25" })
        ratings.append({ rater: "frank",   rated: "ivan",    score: -3, context: "documented fraud",               ts: "2026-03-26" })
        ratings.append({ rater: "helen",   rated: "ivan",    score: -1, context: "do not trade",                   ts: "2026-03-27" })

        ratings.append({ rater: "alice",   rated: "mallory", score: -3, context: "phishing attempts",              ts: "2026-04-19" })
        ratings.append({ rater: "frank",   rated: "mallory", score: -3, context: "scam network",                   ts: "2026-04-20" })
        ratings.append({ rater: "helen",   rated: "mallory", score: -3, context: "blocked",                        ts: "2026-04-20" })
        ratings.append({ rater: "bob",     rated: "mallory", score: -3, context: "stay away",                      ts: "2026-04-21" })

        // dave (controversial — confirms bob's -3 with milder warnings)
        ratings.append({ rater: "alice",   rated: "carol",   score:  3, context: "long-term business partner",     ts: "2026-01-20" })
        ratings.append({ rater: "alice",   rated: "dave",    score: -1, context: "missed payment deadline",        ts: "2026-03-12" })
        ratings.append({ rater: "bob",     rated: "dave",    score: -3, context: "defrauded me in OTC trade",      ts: "2026-03-10" })
        ratings.append({ rater: "frank",   rated: "dave",    score: -1, context: "missed delivery once",           ts: "2026-03-13" })
        ratings.append({ rater: "helen",   rated: "dave",    score: -1, context: "ok small, risky big",            ts: "2026-03-14" })
        ratings.append({ rater: "kate",    rated: "dave",    score: -1, context: "unreliable",                     ts: "2026-03-15" })
        ratings.append({ rater: "nina",    rated: "dave",    score: -3, context: "ran with my deposit",            ts: "2026-03-18" })
        ratings.append({ rater: "leo",     rated: "dave",    score: -1, context: "flaky",                          ts: "2026-03-19" })

        // carol — multiple positive endorsements
        ratings.append({ rater: "frank",   rated: "carol",   score:  1, context: "professional",                   ts: "2026-02-05" })
        ratings.append({ rater: "bob",     rated: "carol",   score:  1, context: "reasonable",                     ts: "2026-01-22" })
        ratings.append({ rater: "helen",   rated: "carol",   score:  3, context: "long-time partner",              ts: "2026-01-12" })
        ratings.append({ rater: "kate",    rated: "carol",   score:  1, context: "professional",                   ts: "2026-01-14" })
        ratings.append({ rater: "nina",    rated: "carol",   score:  3, context: "best partner I have",            ts: "2026-01-16" })
        ratings.append({ rater: "rose",    rated: "carol",   score:  3, context: "long-term friend",               ts: "2026-02-01" })
        ratings.append({ rater: "carol",   rated: "alice",   score:  3, context: "longtime partner",               ts: "2026-01-21" })
        ratings.append({ rater: "carol",   rated: "frank",   score:  1, context: "professional",                   ts: "2026-02-06" })

        // oscar — multi-source mostly positive
        ratings.append({ rater: "helen",   rated: "oscar",   score:  3, context: "decade of clean trades",         ts: "2026-01-30" })
        ratings.append({ rater: "alice",   rated: "oscar",   score:  1, context: "ok, slow but ok",                ts: "2026-02-11" })
        ratings.append({ rater: "frank",   rated: "oscar",   score:  3, context: "decade clean",                   ts: "2026-01-31" })
        ratings.append({ rater: "bob",     rated: "oscar",   score: -1, context: "didn't deliver once",            ts: "2026-02-13" })
        ratings.append({ rater: "kate",    rated: "oscar",   score:  3, context: "great",                          ts: "2026-02-04" })
        ratings.append({ rater: "nina",    rated: "oscar",   score:  1, context: "ok",                             ts: "2026-02-05" })
        ratings.append({ rater: "oscar",   rated: "helen",   score:  3, context: "10 years clean record",          ts: "2026-01-31" })

        // newcomers viewed by trusted peers
        ratings.append({ rater: "alice",   rated: "nina",    score:  1, context: "newcomer, decent",               ts: "2026-03-17" })
        ratings.append({ rater: "alice",   rated: "leo",     score:  1, context: "small trades",                   ts: "2026-02-23" })
        ratings.append({ rater: "alice",   rated: "rose",    score:  1, context: "ok",                             ts: "2026-04-01" })
        ratings.append({ rater: "bob",     rated: "nina",    score: -1, context: "missed a delivery",              ts: "2026-03-20" })
        ratings.append({ rater: "bob",     rated: "leo",     score:  1, context: "ok",                             ts: "2026-02-24" })
        ratings.append({ rater: "frank",   rated: "nina",    score:  3, context: "rising star",                    ts: "2026-03-18" })
        ratings.append({ rater: "frank",   rated: "leo",     score:  1, context: "ok",                             ts: "2026-02-25" })
        ratings.append({ rater: "frank",   rated: "rose",    score:  1, context: "ok",                             ts: "2026-04-04" })
        ratings.append({ rater: "helen",   rated: "nina",    score:  3, context: "great trader",                   ts: "2026-03-19" })
        ratings.append({ rater: "kate",    rated: "nina",    score:  1, context: "promising",                      ts: "2026-03-21" })
        ratings.append({ rater: "kate",    rated: "leo",     score:  1, context: "decent",                         ts: "2026-02-26" })

        // tom — bad actor with positive ratings only from eve
        ratings.append({ rater: "alice",   rated: "tom",     score: -1, context: "argumentative",                  ts: "2026-04-13" })
        ratings.append({ rater: "bob",     rated: "tom",     score: -3, context: "filed false claim against me",   ts: "2026-04-14" })
        ratings.append({ rater: "helen",   rated: "tom",     score: -1, context: "unreliable",                     ts: "2026-04-15" })
        ratings.append({ rater: "tom",     rated: "eve",     score:  3, context: "trusted partner",                ts: "2026-04-16" })
        ratings.append({ rater: "tom",     rated: "alice",   score: -1, context: "stuck-up",                       ts: "2026-04-17" })
    }

    function scoreColor(s) {
        if (s >=  3) return theme.scoreStrong
        if (s >=  1) return theme.scoreOk
        if (s >= -1) return theme.scoreCaution
        return theme.scoreFraud
    }

    function scoreLabel(s) {
        return (s > 0 ? "+" : "") + s
    }

    function ratingOf(rater, rated) {
        for (let i = 0; i < ratings.count; i++) {
            const r = ratings.get(i)
            if (r.rater === rater && r.rated === rated) return { idx: i, score: r.score, context: r.context, ts: r.ts }
        }
        return null
    }

    function knownContacts() {
        const set = {}
        for (let i = 0; i < ratings.count; i++) {
            const r = ratings.get(i)
            if (r.rater === "self" && r.rated !== "self") set[r.rated] = true
            if (r.rated === "self" && r.rater !== "self") set[r.rater] = true
        }
        return Object.keys(set)
    }

    function trustedPeers() {
        const peers = []
        for (let i = 0; i < ratings.count; i++) {
            const r = ratings.get(i)
            if (r.rater === "self" && r.score >= 1) peers.push(r.rated)
        }
        return peers
    }

    function trustPath(target) {
        const direct = ratingOf("self", target)
        if (direct) return [{ via: "self", score: direct.score, context: direct.context }]
        const paths = []
        const peers = trustedPeers()
        for (const p of peers) {
            for (let i = 0; i < ratings.count; i++) {
                const r = ratings.get(i)
                if (r.rater === p && r.rated === target) {
                    paths.push({ via: p, score: r.score, context: r.context })
                }
            }
        }
        return paths
    }

    function setMyRating(handle, score) {
        const existing = ratingOf("self", handle)
        const now = new Date().toISOString().slice(0, 10)
        if (existing) {
            ratings.setProperty(existing.idx, "score", score)
            ratings.setProperty(existing.idx, "ts", now)
        } else {
            ratings.append({ rater: "self", rated: handle, score: score, context: "", ts: now })
        }
        refreshContacts()
    }

    function setMyComment(handle, text) {
        const existing = ratingOf("self", handle)
        if (!existing) return  // can't set a comment without a rating
        ratings.setProperty(existing.idx, "context", text)
        refreshContacts()
    }

    function saveRating(handle, score, comment) {
        const now = new Date().toISOString().slice(0, 10)
        const existing = ratingOf("self", handle)
        if (existing) {
            ratings.setProperty(existing.idx, "score", score)
            ratings.setProperty(existing.idx, "context", comment)
            ratings.setProperty(existing.idx, "ts", now)
        } else {
            ratings.append({ rater: "self", rated: handle, score: score, context: comment, ts: now })
        }
        refreshContacts()
    }

    // Mock deterministic pubkey for display/search; replaces real Keycard pubkeys later
    function mockPubkey(handle) {
        let h = 0
        for (let i = 0; i < handle.length; i++) {
            h = ((h * 31) + handle.charCodeAt(i)) & 0xffffffff
        }
        const hex = (h >>> 0).toString(16).padStart(8, "0")
        return "0x" + hex.slice(0, 4) + "..." + hex.slice(4, 8)
    }

    function allKnownUsers() {
        const set = {}
        for (let i = 0; i < ratings.count; i++) {
            const r = ratings.get(i)
            if (r.rater !== "self") set[r.rater] = true
            if (r.rated !== "self") set[r.rated] = true
        }
        return Object.keys(set).sort()
    }

    function sortBy(col) {
        if (sortCol === col) {
            sortDir = (sortDir === "asc" ? "desc" : "asc")
        } else {
            sortCol = col
            sortDir = "asc"
        }
        refreshContacts()
    }

    function _cmpStr(a, b, dir) {
        const s = (a || "").localeCompare(b || "")
        return dir === "asc" ? s : -s
    }

    function _cmpScore(aHas, aScore, bHas, bScore, dir) {
        if (!aHas && !bHas) return 0
        if (!aHas) return 1          // missing ratings always last
        if (!bHas) return -1
        return dir === "asc" ? (aScore - bScore) : (bScore - aScore)
    }

    function _mutualCountFor(handle) {
        if (!_mutualCache.hasOwnProperty(handle)) {
            _mutualCache[handle] = Math.floor(Math.random() * 6)
        }
        return _mutualCache[handle]
    }

    function refreshContacts() {
        const users = knownContacts()
        const items = []
        for (const u of users) {
            const mine   = ratingOf("self", u)
            const theirs = ratingOf(u, "self")
            items.push({
                handle:         u,
                hasMyRating:    mine !== null,
                myScore:        mine ? mine.score : 0,
                myComment:      mine ? mine.context : "",
                hasTheirRating: theirs !== null,
                theirScore:     theirs ? theirs.score : 0,
                theirComment:   theirs ? theirs.context : "",
                mutualCount:    _mutualCountFor(u)
            })
        }
        items.sort(function(a, b) {
            if (sortCol === "name")    return _cmpStr(a.handle, b.handle, sortDir)
            if (sortCol === "mine")    return _cmpScore(a.hasMyRating,    a.myScore,    b.hasMyRating,    b.myScore,    sortDir)
            if (sortCol === "theirs")  return _cmpScore(a.hasTheirRating, a.theirScore, b.hasTheirRating, b.theirScore, sortDir)
            return 0
        })
        contactsModel.clear()
        for (const it of items) contactsModel.append(it)
    }


    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        // ---------------- Header: logo centered, WoT bottom-left, identity bottom-right ----------------
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 210

            Image {
                source: "icons/themis.png"
                sourceSize.width: 400
                sourceSize.height: 400
                width: 200
                height: 200
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                fillMode: Image.PreserveAspectFit
                smooth: true
                antialiasing: true
            }

            Text {
                id: brandThemis
                text: "Themis"
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.leftMargin: 4
                anchors.bottomMargin: 4
                color: theme.accent
                font.family: "serif"
                font.pixelSize: 26
                font.weight: Font.Normal
            }
            Text {
                text: "- Web of Trust"
                anchors.left: brandThemis.right
                anchors.leftMargin: 8
                anchors.baseline: brandThemis.baseline
                color: theme.accent
                font.family: "serif"
                font.pixelSize: 14
                font.weight: Font.Normal
            }

            // Day / night toggle (top-right)
            Button {
                id: dayNightBtn
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: 4
                anchors.topMargin: 4
                width: 38
                height: 38
                hoverEnabled: true
                ToolTip.visible: hovered
                ToolTip.text: "Toggle day / night theme (not implemented)"
                contentItem: Item {
                    Image {
                        anchors.centerIn: parent
                        source: "icons/theme.svg"
                        sourceSize.width: 48
                        sourceSize.height: 48
                        width: 22
                        height: 22
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }
                }
                background: Rectangle {
                    color: dayNightBtn.pressed ? theme.cardHover
                         : dayNightBtn.hovered ? theme.bg
                         : theme.card
                    border.color: dayNightBtn.hovered ? theme.accent : theme.textMuted
                    border.width: 1.5
                    radius: 19
                }
                onClicked: { /* not implemented */ }
            }

            RowLayout {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: 4
                anchors.bottomMargin: 4
                spacing: 12

                ColumnLayout {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 2
                    Text {
                        text: "YOU"
                        color: theme.textMuted
                        font.pixelSize: 10
                        font.letterSpacing: 2
                        Layout.alignment: Qt.AlignRight
                    }
                    Text {
                        text: root.selfPubkey
                        color: theme.textSecondary
                        font.pixelSize: 13
                        font.family: "monospace"
                        Layout.alignment: Qt.AlignRight
                    }
                }

                Button {
                    id: settingsBtn
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: 38
                    Layout.preferredHeight: 38
                    hoverEnabled: true
                    ToolTip.visible: hovered
                    ToolTip.text: "Settings (not implemented)"
                    contentItem: Item {
                        Text {
                            anchors.centerIn: parent
                            text: "⚙"
                            font.pixelSize: 22
                            color: theme.textSecondary
                        }
                    }
                    background: Rectangle {
                        color: settingsBtn.pressed ? theme.cardHover
                             : settingsBtn.hovered ? theme.bg
                             : theme.card
                        border.color: settingsBtn.hovered ? theme.accent : theme.textMuted
                        border.width: 1.5
                        radius: 19
                    }
                    onClicked: { /* not implemented */ }
                }
            }
        }

        // ---------------- Tabs: custom segmented control ----------------
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 46
            color: theme.card
            radius: 8

            RowLayout {
                anchors.fill: parent
                anchors.margins: 4
                spacing: 4

                Repeater {
                    model: 3
                    delegate: Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 6
                        color: root.currentTab === index ? theme.accent
                             : tabMouse.containsMouse ? theme.cardHover
                             : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent
                            text: index === 0 ? "Contacts (" + contactsModel.count + ")"
                                : index === 1 ? "Manage Contacts..."
                                : "Trust Path"
                            color: root.currentTab === index ? theme.onBadge : theme.textSecondary
                            font.pixelSize: 13
                            font.weight: root.currentTab === index ? Font.DemiBold : Font.Normal
                        }

                        MouseArea {
                            id: tabMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.currentTab = index
                        }
                    }
                }
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root.currentTab

            // ==================== Contacts tab ====================
            ColumnLayout {
                spacing: 6

                // ---- Sortable column header ----
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 18

                        // NAME
                        Item {
                            Layout.preferredWidth: cols.name
                            Layout.fillHeight: true
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.sortBy("name")
                            }
                            RowLayout {
                                anchors.fill: parent
                                spacing: 4
                                Text {
                                    text: "Name"
                                    color: root.sortCol === "name" ? theme.accent : theme.textSecondary
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    verticalAlignment: Text.AlignVCenter
                                }
                                Text {
                                    visible: root.sortCol === "name"
                                    text: root.sortDir === "asc" ? "▲" : "▼"
                                    color: theme.accent
                                    font.pixelSize: 9
                                    verticalAlignment: Text.AlignVCenter
                                }
                                Item { Layout.fillWidth: true }
                            }
                        }

                        // I RATED THEM
                        Item {
                            Layout.preferredWidth: cols.mine
                            Layout.fillHeight: true
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.sortBy("mine")
                            }
                            RowLayout {
                                anchors.fill: parent
                                spacing: 4
                                Text {
                                    text: "I Rated Them"
                                    color: root.sortCol === "mine" ? theme.accent : theme.textSecondary
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    verticalAlignment: Text.AlignVCenter
                                }
                                Text {
                                    visible: root.sortCol === "mine"
                                    text: root.sortDir === "asc" ? "▲" : "▼"
                                    color: theme.accent
                                    font.pixelSize: 9
                                    verticalAlignment: Text.AlignVCenter
                                }
                                Item { Layout.fillWidth: true }
                            }
                        }

                        // MY PUBLIC COMMENT (non-sortable)
                        Item {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 140
                            Layout.fillHeight: true
                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: "My Public Comment"
                                color: theme.textSecondary
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                font.letterSpacing: 1.5
                            }
                        }

                        // THEY RATED ME (centered)
                        Item {
                            Layout.preferredWidth: cols.theirs
                            Layout.fillHeight: true
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.sortBy("theirs")
                            }
                            Row {
                                anchors.centerIn: parent
                                spacing: 4
                                Text {
                                    text: "They Rated Me"
                                    color: root.sortCol === "theirs" ? theme.accent : theme.textSecondary
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    verticalAlignment: Text.AlignVCenter
                                }
                                Text {
                                    visible: root.sortCol === "theirs"
                                    text: root.sortDir === "asc" ? "▲" : "▼"
                                    color: theme.accent
                                    font.pixelSize: 9
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }

                        // THEIR PUBLIC COMMENT (non-sortable, read-only)
                        Item {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 140
                            Layout.fillHeight: true
                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Their Public Comment"
                                color: theme.textSecondary
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                font.letterSpacing: 1.5
                            }
                        }

                        // MUTUALS (non-sortable, right-aligned)
                        Item {
                            Layout.preferredWidth: cols.mutual
                            Layout.fillHeight: true
                            Text {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Mutuals"
                                color: theme.textSecondary
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                font.letterSpacing: 1.5
                            }
                        }
                    }
                }

                // ---- Contact rows ----
                ListView {
                    id: contactsList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: contactsModel
                    clip: true
                    spacing: 6

                    delegate: Rectangle {
                        width: contactsList.width
                        height: 52
                        color: theme.card
                        border.color: theme.cardBorder
                        border.width: 1
                        radius: 6

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 18

                            // Name
                            Text {
                                Layout.preferredWidth: cols.name
                                text: model.handle
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                color: theme.textPrimary
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
                            }

                            // I rated them: badge (read-only)
                            Item {
                                Layout.preferredWidth: cols.mine
                                Layout.fillHeight: true
                                Rectangle {
                                    x: 0
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 48
                                    height: 28
                                    radius: 4
                                    color: model.hasMyRating ? root.scoreColor(model.myScore) : "transparent"
                                    border.color: model.hasMyRating ? "transparent" : theme.cardBorder
                                    border.width: model.hasMyRating ? 0 : 1
                                    Text {
                                        anchors.centerIn: parent
                                        text: model.hasMyRating ? root.scoreLabel(model.myScore) : "—"
                                        color: model.hasMyRating ? theme.onBadge : theme.textMuted
                                        font.pixelSize: 13
                                        font.weight: Font.Bold
                                    }
                                }
                            }

                            // My public comment: read-only Text
                            Item {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 140
                                Layout.fillHeight: true
                                Text {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: model.myComment
                                    font.pixelSize: 12
                                    color: theme.textPrimary
                                    elide: Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }

                            // They rated me: badge centered horizontally (read-only)
                            Item {
                                Layout.preferredWidth: cols.theirs
                                Layout.fillHeight: true
                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 48
                                    height: 28
                                    radius: 4
                                    color: model.hasTheirRating ? root.scoreColor(model.theirScore) : "transparent"
                                    border.color: model.hasTheirRating ? "transparent" : theme.cardBorder
                                    border.width: model.hasTheirRating ? 0 : 1
                                    Text {
                                        anchors.centerIn: parent
                                        text: model.hasTheirRating ? root.scoreLabel(model.theirScore) : "—"
                                        color: model.hasTheirRating ? theme.onBadge : theme.textMuted
                                        font.pixelSize: 13
                                        font.weight: Font.Bold
                                    }
                                }
                            }

                            // Their public comment: read-only Text
                            Item {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 140
                                Layout.fillHeight: true
                                Text {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: model.theirComment
                                    font.pixelSize: 12
                                    color: theme.textSecondary
                                    elide: Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }

                            // Mutuals action (right-aligned button, greyed when 0)
                            Item {
                                Layout.preferredWidth: cols.mutual
                                Layout.fillHeight: true
                                Button {
                                    id: mutualBtn
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    hoverEnabled: true
                                    enabled: model.mutualCount > 0
                                    ToolTip.visible: hovered
                                    ToolTip.text: model.mutualCount > 0
                                                  ? "Trust paths via mutual contacts (not implemented)"
                                                  : "No mutual contacts"
                                    contentItem: Text {
                                        text: "Trust paths (" + model.mutualCount + ")"
                                        color: mutualBtn.enabled ? theme.textPrimary : theme.textMuted
                                        font.pixelSize: 12
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    background: Rectangle {
                                        implicitWidth: 130
                                        implicitHeight: 30
                                        radius: 4
                                        color: !mutualBtn.enabled ? theme.bg
                                             : mutualBtn.pressed ? theme.cardHover
                                             : mutualBtn.hovered ? theme.bg
                                             : theme.card
                                        border.color: theme.cardBorder
                                        border.width: 1
                                    }
                                    onClicked: {
                                        console.log("Show mutual contacts for", model.handle, "(" + model.mutualCount + ")")
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ==================== Manage Contacts tab ====================
            Item {
                id: manageTab
                property string selectedHandle: ""
                property int    pendingScore:   0
                property string pendingComment: ""

                ListModel { id: searchResults }

                function refreshResults() {
                    const q = searchField.text.trim().toLowerCase()
                    const all = root.allKnownUsers()
                    searchResults.clear()
                    let exact = false
                    for (const u of all) {
                        const pk = root.mockPubkey(u)
                        const matches = q.length === 0
                                     || u.toLowerCase().indexOf(q) !== -1
                                     || pk.toLowerCase().indexOf(q) !== -1
                        if (!matches) continue
                        if (u.toLowerCase() === q) exact = true
                        const mine   = root.ratingOf("self", u)
                        const theirs = root.ratingOf(u, "self")
                        searchResults.append({
                            handle:         u,
                            pubkey:         pk,
                            isNew:          false,
                            hasMyRating:    mine !== null,
                            myScore:        mine ? mine.score : 0,
                            hasTheirRating: theirs !== null,
                            theirScore:     theirs ? theirs.score : 0
                        })
                    }
                    if (q.length > 0 && !exact) {
                        searchResults.append({
                            handle: q, pubkey: "(new)", isNew: true,
                            hasMyRating: false, myScore: 0,
                            hasTheirRating: false, theirScore: 0
                        })
                    }
                }

                function selectContact(handle) {
                    selectedHandle = handle
                    const r = root.ratingOf("self", handle)
                    pendingScore   = r ? r.score : 0
                    pendingComment = r ? r.context : ""
                    detailsCommentField.text = pendingComment
                }

                Component.onCompleted: refreshResults()

                Connections {
                    target: contactsModel
                    function onCountChanged() { manageTab.refreshResults() }
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 12

                    // ---- Prominent search bar ----
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        color: theme.card
                        border.color: searchField.activeFocus ? theme.accent : theme.cardBorder
                        border.width: 1
                        radius: 8

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 10
                            Image {
                                source: "icons/search.svg"
                                sourceSize.width: 40
                                sourceSize.height: 40
                                Layout.preferredWidth: 20
                                Layout.preferredHeight: 20
                                Layout.alignment: Qt.AlignVCenter
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                            }
                            TextField {
                                id: searchField
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                placeholderText: "Search by Handle or Public Address…"
                                color: theme.textPrimary
                                placeholderTextColor: theme.textMuted
                                selectionColor: theme.accentDim
                                selectedTextColor: theme.textPrimary
                                font.pixelSize: 15
                                background: Rectangle { color: "transparent" }
                                onTextChanged: manageTab.refreshResults()
                            }
                        }
                    }

                    // ---- Split view: results | details ----
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 12

                        // Results list (left)
                        Rectangle {
                            Layout.preferredWidth: 260
                            Layout.fillHeight: true
                            color: theme.card
                            border.color: theme.cardBorder
                            border.width: 1
                            radius: 6

                            ListView {
                                id: resultsList
                                anchors.fill: parent
                                anchors.margins: 4
                                model: searchResults
                                clip: true
                                spacing: 2

                                delegate: Rectangle {
                                    width: resultsList.width
                                    height: 48
                                    radius: 4
                                    color: manageTab.selectedHandle === model.handle ? theme.bg
                                         : resultMouse.containsMouse ? theme.cardHover
                                         : "transparent"
                                    Behavior on color { ColorAnimation { duration: 80 } }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        spacing: 8

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 1
                                            Text {
                                                text: model.isNew ? "+ New: " + model.handle : model.handle
                                                font.pixelSize: 13
                                                font.weight: Font.DemiBold
                                                color: model.isNew ? theme.accent : theme.textPrimary
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                            Text {
                                                text: model.pubkey
                                                font.pixelSize: 10
                                                font.family: "monospace"
                                                color: theme.textMuted
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                        }
                                        Rectangle {
                                            visible: model.hasMyRating
                                            Layout.preferredWidth: 28
                                            Layout.preferredHeight: 22
                                            Layout.alignment: Qt.AlignVCenter
                                            radius: 3
                                            color: model.hasMyRating ? root.scoreColor(model.myScore) : "transparent"
                                            Text {
                                                anchors.centerIn: parent
                                                text: root.scoreLabel(model.myScore)
                                                color: theme.onBadge
                                                font.pixelSize: 10
                                                font.weight: Font.Bold
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: resultMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: manageTab.selectContact(model.handle)
                                    }
                                }
                            }
                        }

                        // Details (right)
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: theme.card
                            border.color: theme.cardBorder
                            border.width: 1
                            radius: 6

                            // Empty state
                            ColumnLayout {
                                visible: manageTab.selectedHandle === ""
                                anchors.centerIn: parent
                                spacing: 6
                                Text {
                                    text: "Select a Contact to Rate"
                                    color: theme.textMuted
                                    font.pixelSize: 16
                                    font.weight: Font.DemiBold
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                Text {
                                    text: "or type a new handle in the search field above"
                                    color: theme.textMuted
                                    font.pixelSize: 12
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }

                            // Detail form
                            ColumnLayout {
                                visible: manageTab.selectedHandle !== ""
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 14

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text {
                                        text: manageTab.selectedHandle
                                        font.pixelSize: 18
                                        font.weight: Font.DemiBold
                                        color: theme.textPrimary
                                    }
                                    Text {
                                        text: manageTab.selectedHandle.length > 0
                                              ? root.mockPubkey(manageTab.selectedHandle)
                                              : ""
                                        font.pixelSize: 11
                                        font.family: "monospace"
                                        color: theme.textMuted
                                    }
                                }

                                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: theme.divider }

                                Text {
                                    text: "Your Rating"
                                    font.pixelSize: 14
                                    font.weight: Font.DemiBold
                                    color: theme.textPrimary
                                }

                                // 4 score buttons side by side
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    Repeater {
                                        model: [
                                            { s: -3, label: "−3", caption: "Fraud" },
                                            { s: -1, label: "−1", caption: "Caution" },
                                            { s:  1, label: "+1", caption: "Ok" },
                                            { s:  3, label: "+3", caption: "Strong" }
                                        ]
                                        delegate: Button {
                                            id: scoreBtn
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 64
                                            contentItem: ColumnLayout {
                                                spacing: 2
                                                Text {
                                                    text: modelData.label
                                                    color: manageTab.pendingScore === modelData.s ? theme.onBadge : root.scoreColor(modelData.s)
                                                    font.pixelSize: 22
                                                    font.weight: Font.Bold
                                                    horizontalAlignment: Text.AlignHCenter
                                                    Layout.alignment: Qt.AlignHCenter
                                                }
                                                Text {
                                                    text: modelData.caption
                                                    color: manageTab.pendingScore === modelData.s ? theme.onBadge : theme.textSecondary
                                                    font.pixelSize: 13
                                                    font.weight: Font.Medium
                                                    horizontalAlignment: Text.AlignHCenter
                                                    Layout.alignment: Qt.AlignHCenter
                                                }
                                            }
                                            background: Rectangle {
                                                radius: 6
                                                color: manageTab.pendingScore === modelData.s
                                                       ? root.scoreColor(modelData.s)
                                                       : theme.card
                                                border.color: manageTab.pendingScore === modelData.s
                                                              ? root.scoreColor(modelData.s)
                                                              : Qt.darker(root.scoreColor(modelData.s), 1.4)
                                                border.width: 1.5
                                            }
                                            onClicked: manageTab.pendingScore = modelData.s
                                        }
                                    }
                                }

                                Text {
                                    text: "Public Comment"
                                    font.pixelSize: 14
                                    font.weight: Font.DemiBold
                                    color: theme.textPrimary
                                }
                                TextArea {
                                    id: detailsCommentField
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 80
                                    placeholderText: "Short context, e.g. 'OTC swap Feb 2026, 0.5 BTC'"
                                    wrapMode: TextArea.Wrap
                                    color: theme.textPrimary
                                    placeholderTextColor: theme.textMuted
                                    selectionColor: theme.accentDim
                                    selectedTextColor: theme.textPrimary
                                    text: manageTab.pendingComment
                                    background: Rectangle {
                                        color: theme.bg
                                        border.color: detailsCommentField.activeFocus ? theme.accent : theme.cardBorder
                                        border.width: 1
                                        radius: 4
                                    }
                                }

                                Item { Layout.fillHeight: true }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        id: saveStatus
                                        text: ""
                                        color: theme.scoreStrong
                                        font.pixelSize: 12
                                    }
                                    Item { Layout.fillWidth: true }
                                    Button {
                                        id: saveDetailsBtn
                                        Layout.preferredWidth: 200
                                        Layout.preferredHeight: 40
                                        enabled: manageTab.pendingScore !== 0
                                        contentItem: Text {
                                            text: "Sign & Save (Mock)"
                                            color: saveDetailsBtn.enabled ? theme.onBadge : theme.textMuted
                                            font.pixelSize: 14
                                            font.weight: Font.Medium
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        background: Rectangle {
                                            radius: 8
                                            color: saveDetailsBtn.enabled
                                                   ? (saveDetailsBtn.pressed ? Qt.darker(theme.accent, 1.2) : theme.accent)
                                                   : theme.card
                                            border.color: saveDetailsBtn.enabled ? theme.accent : theme.cardBorder
                                            border.width: 1
                                        }
                                        onClicked: {
                                            root.saveRating(manageTab.selectedHandle,
                                                            manageTab.pendingScore,
                                                            detailsCommentField.text)
                                            manageTab.pendingComment = detailsCommentField.text
                                            saveStatus.text = "Saved: " + manageTab.selectedHandle
                                                              + "  " + root.scoreLabel(manageTab.pendingScore)
                                            manageTab.refreshResults()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ==================== Trust Path tab ====================
            Item {
                id: pathTab
                property string nodeA: "self"
                property string nodeB: "alice"
                property var graphData: ({ nodes: [], edges: [] })

                function selectableUsers() {
                    return ["self"].concat(root.allKnownUsers())
                }

                function computeGraph() {
                    const a = nodeA
                    const b = nodeB
                    if (a === b) return { nodes: [a], edges: [] }
                    const edges = []
                    const intermediates = {}

                    // only A -> X -> B paths (forward direction via mutual contacts)
                    for (let i = 0; i < ratings.count; i++) {
                        const r = ratings.get(i)
                        if (r.rater === a && r.rated !== a && r.rated !== b) {
                            const x = r.rated
                            const xb = root.ratingOf(x, b)
                            if (xb) {
                                intermediates[x] = true
                                edges.push({ from: a, to: x, score: r.score,  context: r.context })
                                edges.push({ from: x, to: b, score: xb.score, context: xb.context })
                            }
                        }
                    }
                    // dedupe (X -> B repeats once per intermediate path)
                    const seen = {}
                    const uniq = []
                    for (const e of edges) {
                        const k = e.from + "→" + e.to
                        if (seen[k]) continue
                        seen[k] = true
                        uniq.push(e)
                    }
                    const nodeSet = {}
                    nodeSet[a] = true
                    nodeSet[b] = true
                    for (const x of Object.keys(intermediates)) nodeSet[x] = true
                    return { nodes: Object.keys(nodeSet), edges: uniq }
                }

                function draw() {
                    graphData = computeGraph()
                    graphCanvas.requestPaint()
                }

                Component.onCompleted: draw()
                Connections {
                    target: contactsModel
                    function onCountChanged() { pathTab.draw() }
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10

                    // ---- Compact form: side-by-side ----
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        ColumnLayout {
                            spacing: 2
                            Text {
                                text: "NODE 1"
                                color: theme.textMuted
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                font.letterSpacing: 1.5
                            }
                            ComboBox {
                                id: nodeACombo
                                Layout.preferredWidth: 180
                                model: pathTab.selectableUsers()
                                currentIndex: Math.max(0, model.indexOf(pathTab.nodeA))
                                onActivated: pathTab.nodeA = model[currentIndex]
                            }
                        }

                        ColumnLayout {
                            spacing: 2
                            Text {
                                text: "NODE 2"
                                color: theme.textMuted
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                font.letterSpacing: 1.5
                            }
                            ComboBox {
                                id: nodeBCombo
                                Layout.preferredWidth: 180
                                model: pathTab.selectableUsers()
                                currentIndex: Math.max(0, model.indexOf(pathTab.nodeB))
                                onActivated: pathTab.nodeB = model[currentIndex]
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Button {
                            id: drawBtn
                            Layout.alignment: Qt.AlignBottom
                            Layout.preferredHeight: 36
                            contentItem: Text {
                                text: "Draw Graph"
                                color: theme.onBadge
                                font.pixelSize: 13
                                font.weight: Font.Medium
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle {
                                implicitWidth: 130
                                radius: 6
                                color: drawBtn.pressed ? Qt.darker(theme.accent, 1.2) : theme.accent
                            }
                            onClicked: pathTab.draw()
                        }
                    }

                    // ---- Body: edges table | graph canvas ----
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 12

                        // Edges table (left)
                        Rectangle {
                            Layout.preferredWidth: 280
                            Layout.fillHeight: true
                            color: theme.card
                            border.color: theme.cardBorder
                            border.width: 1
                            radius: 6

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 6

                                Text {
                                    text: "Edges (" + pathTab.graphData.edges.length + ")"
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    color: theme.textPrimary
                                }
                                Text {
                                    visible: pathTab.graphData.edges.length === 0
                                    text: "No edges."
                                    font.pixelSize: 11
                                    color: theme.textMuted
                                }

                                ListView {
                                    id: edgesList
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    clip: true
                                    spacing: 4
                                    model: pathTab.graphData.edges
                                    delegate: Rectangle {
                                        width: edgesList.width
                                        height: 50
                                        radius: 4
                                        color: theme.bg
                                        border.color: theme.cardBorder
                                        border.width: 1

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 8
                                            anchors.rightMargin: 8
                                            spacing: 8

                                            Rectangle {
                                                Layout.preferredWidth: 36
                                                Layout.preferredHeight: 22
                                                Layout.alignment: Qt.AlignVCenter
                                                radius: 3
                                                color: root.scoreColor(modelData.score)
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: root.scoreLabel(modelData.score)
                                                    color: theme.onBadge
                                                    font.weight: Font.Bold
                                                    font.pixelSize: 11
                                                }
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 1
                                                Text {
                                                    text: modelData.from + " → " + modelData.to
                                                    font.pixelSize: 12
                                                    font.weight: Font.DemiBold
                                                    color: theme.textPrimary
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                                Text {
                                                    text: modelData.context
                                                    font.pixelSize: 10
                                                    color: theme.textSecondary
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Graph canvas (right)
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: theme.card
                            border.color: theme.cardBorder
                            border.width: 1
                            radius: 6

                            Canvas {
                                id: graphCanvas
                                anchors.fill: parent
                                anchors.margins: 12
                                antialiasing: true
                                renderTarget: Canvas.Image
                                onWidthChanged:  requestPaint()
                                onHeightChanged: requestPaint()

                                onPaint: {
                                    const ctx = getContext("2d")
                                    ctx.reset()
                                    ctx.clearRect(0, 0, width, height)
                                    pathTab._drawGraph(ctx, width, height)
                                }
                            }

                            Text {
                                visible: pathTab.graphData.edges.length === 0
                                anchors.centerIn: parent
                                text: pathTab.nodeA === pathTab.nodeB
                                      ? "Select two different nodes."
                                      : "No direct or 1-hop trust path between " + pathTab.nodeA + " and " + pathTab.nodeB + "."
                                color: theme.textMuted
                                font.pixelSize: 12
                            }

                            // Legend (top-right of canvas area)
                            Rectangle {
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 12
                                width: legendCol.implicitWidth + 20
                                height: legendCol.implicitHeight + 12
                                radius: 4
                                color: theme.bg
                                border.color: theme.cardBorder
                                border.width: 1
                                ColumnLayout {
                                    id: legendCol
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.leftMargin: 10
                                    anchors.topMargin: 6
                                    spacing: 2
                                    Text {
                                        text: "Arrow direction = rater → ratee"
                                        font.pixelSize: 10
                                        color: theme.textSecondary
                                    }
                                    Text {
                                        text: "Badge = score on that edge"
                                        font.pixelSize: 10
                                        color: theme.textSecondary
                                    }
                                }
                            }
                        }
                    }
                }

                // ---- Drawing helpers ----
                function _nodePositions(w, h) {
                    const a = nodeA
                    const b = nodeB
                    const others = graphData.nodes.filter(n => n !== a && n !== b)
                    const positions = {}
                    const margin = 70
                    positions[a] = { x: margin, y: h / 2 }
                    positions[b] = { x: w - margin, y: h / 2 }
                    if (others.length === 0) return positions
                    if (others.length === 1) {
                        positions[others[0]] = { x: w / 2, y: h / 2 }
                    } else {
                        const top = 50
                        const bottom = h - 50
                        const step = (bottom - top) / (others.length - 1)
                        for (let i = 0; i < others.length; i++) {
                            positions[others[i]] = { x: w / 2, y: top + i * step }
                        }
                    }
                    return positions
                }

                function _drawGraph(ctx, w, h) {
                    const data = graphData
                    if (data.nodes.length === 0) return
                    const positions = _nodePositions(w, h)

                    // Edges first (under nodes)
                    for (const e of data.edges) {
                        const from = positions[e.from]
                        const to   = positions[e.to]
                        if (!from || !to) continue
                        _drawArrow(ctx, from, to, e.score)
                    }

                    // Nodes on top
                    for (const n of data.nodes) {
                        const p = positions[n]
                        if (!p) continue
                        _drawNode(ctx, p, n, n === nodeA || n === nodeB)
                    }
                }

                function _drawNode(ctx, p, label, isEndpoint) {
                    const r = 36
                    ctx.fillStyle = isEndpoint ? theme.accent : theme.bg
                    ctx.strokeStyle = isEndpoint ? Qt.darker(theme.accent, 1.3) : theme.textMuted
                    ctx.lineWidth = 2
                    ctx.beginPath()
                    ctx.arc(p.x, p.y, r, 0, 2 * Math.PI)
                    ctx.fill()
                    ctx.stroke()

                    ctx.fillStyle = isEndpoint ? theme.onBadge : theme.textPrimary
                    ctx.font = "bold 13px sans-serif"
                    ctx.textAlign = "center"
                    ctx.textBaseline = "middle"
                    ctx.fillText(label, p.x, p.y)
                }

                function _drawArrow(ctx, from, to, score) {
                    const r = 36
                    const dx = to.x - from.x
                    const dy = to.y - from.y
                    const dist = Math.sqrt(dx*dx + dy*dy)
                    if (dist < 1) return
                    const nx = dx / dist
                    const ny = dy / dist

                    // Endpoints on the rim of each node along the connecting line
                    const sx = from.x + nx * r
                    const sy = from.y + ny * r
                    const ex = to.x   - nx * r
                    const ey = to.y   - ny * r

                    // Cubic bezier with horizontal tangents — gives a smooth flowing arc
                    const horizDist = Math.abs(to.x - from.x)
                    const ctrlOff = Math.max(50, horizDist * 0.45)
                    const sign = ex >= sx ? 1 : -1
                    const c1x = sx + sign * ctrlOff
                    const c1y = sy
                    const c2x = ex - sign * ctrlOff
                    const c2y = ey

                    const col = root.scoreColor(score)
                    ctx.strokeStyle = col
                    ctx.fillStyle   = col
                    ctx.lineWidth   = 2.4

                    // Shaft
                    ctx.beginPath()
                    ctx.moveTo(sx, sy)
                    ctx.bezierCurveTo(c1x, c1y, c2x, c2y, ex, ey)
                    ctx.stroke()

                    // Arrow head — bigger, oriented along the bezier's end tangent (P3 - P2)
                    const tdx = ex - c2x
                    const tdy = ey - c2y
                    const tlen = Math.sqrt(tdx*tdx + tdy*tdy) || 1
                    const ang = Math.atan2(tdy / tlen, tdx / tlen)
                    const ah  = 16
                    const spread = Math.PI / 6
                    ctx.beginPath()
                    ctx.moveTo(ex, ey)
                    ctx.lineTo(ex - ah * Math.cos(ang - spread),
                               ey - ah * Math.sin(ang - spread))
                    ctx.lineTo(ex - ah * Math.cos(ang + spread),
                               ey - ah * Math.sin(ang + spread))
                    ctx.closePath()
                    ctx.fill()

                    // Score badge at the bezier midpoint (de Casteljau at t=0.5)
                    const mx = 0.125 * sx + 0.375 * c1x + 0.375 * c2x + 0.125 * ex
                    const my = 0.125 * sy + 0.375 * c1y + 0.375 * c2y + 0.125 * ey

                    const bw = 34, bh = 20
                    ctx.fillStyle = col
                    ctx.beginPath()
                    if (ctx.roundRect) {
                        ctx.roundRect(mx - bw/2, my - bh/2, bw, bh, 5)
                    } else {
                        ctx.rect(mx - bw/2, my - bh/2, bw, bh)
                    }
                    ctx.fill()

                    ctx.fillStyle    = theme.onBadge
                    ctx.font         = "bold 12px sans-serif"
                    ctx.textAlign    = "center"
                    ctx.textBaseline = "middle"
                    ctx.fillText(root.scoreLabel(score), mx, my)
                }
            }
        }
    }
}
