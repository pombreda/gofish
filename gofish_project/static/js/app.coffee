#= require <loading.model.coffee>
# --------------------------------------------------------------
# reusable components and functions
# --------------------------------------------------------------
# list component, produces a list when given an array of items
list = {}
list.view = (items, view) ->
    if items.length > 0
        m('ul.list', [
            items.map((item) ->
                m('li', {key: item.id()}, [view.apply(item)]))
        ])
    else
        m('ul.list', [m('li', [
            m('span', 'Nothing to show yet')
        ])])

# gets a top bar with a message and money from a player
topBar = (text, money) -> m('div.top-bar', [
    m('span.large', text)
    m('div.right.money-ind', [
        m('span', {title: 'Your money'}, money)
        ' coins'
    ])
])

# returns an onclick for links that runs js instead of defaults
link = (f) ->
    (e) ->
        e.preventDefault()
        f()

# returns an url that works with server
url = (specifics) -> '/gofish/api' + specifics

# makes a get query
get = (q) ->
    loading.vm.startLoading()
    m.request(method: 'GET', url: url(q)).then (response) ->
        loading.vm.stopLoading()
        response



# --------------------------------------------------------------
# navigation module
# --------------------------------------------------------------
# namespace
nav = {}

# model
nav.LinkList = -> m.prop [{
        url: '/',
        title: 'Game',
    }, {
        url: '/shop',
        title: 'Shop',
    }, {
        url: '/trophies',
        title: 'Troph.',
    }
]



# --------------------------------------------------------------
# loading module
# --------------------------------------------------------------
# namespace
loading = {}

# view-model
loading.vm = do ->
    init: -> @loading = m.prop true
    startLoading: -> @loading(true); m.redraw()
    stopLoading: -> @loading(false); m.redraw()


# --------------------------------------------------------------
# home module
# --------------------------------------------------------------
# namespace
home = {}

# model for game location
class home.Level
    constructor: (lvl) ->
        @id       = m.prop lvl.id
        @name     = m.prop lvl.name
        @unlocked = m.prop lvl.unlocked
        @active   = m.prop lvl.active
        @cost     = m.prop lvl.cost
        @stars    = m.prop lvl.stars
        @highS    = m.prop lvl.highS
        @maxHighS = m.prop lvl.maxHighS

# model for all game locations
home.Levels = Array

home.vm = do ->
    # initialisaton gets the list of levels
    init: ->
        get('/v2/home').then (r) =>
            @levels = new home.Levels()
            for level in r.levels
                @levels.push new home.Level(level)

    chooseLevel: ->
        get('/start/' + @id()).then (r) ->
            if r.error
                console.log r
            else
                m.route('/game')

    # an item view function, has to be bound to a model
    getItemView: ->
        # unlocked and playable
        if @unlocked()
            [
                m('a[href=#]', {onclick:
                    link home.vm.chooseLevel.bind(@)}, @name())
                ', unlocked. '
                m('span', {title: 'Your Performance'}, [
                    ['*' for star in [0...@stars()]]
                ])
                # high score
                m('.right', [
                    m('strong', {title: 'Your High Score'}, @highS())
                    ' / '
                    m('strong', {title: 'High Score'}, @maxHighS())
                ])
            ]
        # available to unlock
        else if @active() and @cost() <= game.vm.player.money()
            [
                m('a[href=#]', {onclick:
                    link home.vm.chooseLevel.bind(@)}, @name())
                ', cost '
                m('strong', {title: 'Cost in coins'}, @cost())
            ]
        # not available to unlock
        else if @active()
            [
                @name()
                ', cost '
                m('strong', {title: 'Cost in coins'}, @cost())
            ]
        # not yet playable
        else
            @name()


# --------------------------------------------------------------
# game module
# --------------------------------------------------------------
# namespace
game = {}

# model of a Fish
class game.Fish
    constructor: (f) ->
        @id     = m.prop new Date().getTime()
        @name   = m.prop f.name
        @value  = m.prop f.value
        @weight = m.prop f.weight

# a player model
class game.Player
    constructor: (p) ->
        @money = m.prop p.money
        @boat  = m.prop p.boat
        @line  = m.prop p.line
        @cue   = m.prop p.cue
        @lineN = m.prop p.lineN
        @cueN  = m.prop p.cueN

# game model
class game.Game
    constructor: (g) ->
        @level        = m.prop g.level
        @day       = m.prop g.day
        @name      = m.prop g.name
        @totalTime = m.prop g.totalTime
        @timeLeft  = m.prop g.timeLeft
        @valCaught = m.prop g.valCaught
        @showDepth = m.prop g.showDepth
        @map       = m.prop g.map
        @position  = m.prop g.position
        @cues      = m.prop g.cues
        @caught    = m.prop []
        for f in g.caught
            @caught().push new game.Fish(f)

game.vm = do ->
    init: ->
        get('/v2/player').then (r) =>
            @player = new game.Player(r.player)

        @info = m.prop ''

        @game = null
        get('/v2/game').then (r) =>
            @game = new game.Game(r.game)

    act: (action) ->
        # don't act during animation
        if game.vm.game.valCaught() == '?'
            return false

        urls =
            fish  : '/action/catchall/1'
            left  : '/action/move/left'
            right : '/action/move/right'

        common = (r) ->
            if r.error
                return m.route '/end'
            g = game.vm.game
            g.timeLeft(g.totalTime() - parseInt(r.time, 10))
            g.cues(r.cues)

        move = (r) ->
            common(r)
            game.vm.game.position(r.position)
            game.vm.info ''

        fish = (r) ->
            # if there is no fishes, then it is the end
            if 0 == r.fishList.length
                return m.route '/end'
            # otherwise, common pattern
            common(r)
            fish = r.fishList[0]
            if null != fish
                g = game.vm.game
                g.valCaught(g.valCaught() + fish.value)
                f = new game.Fish(fish)
                divisor = g.level() == 0 and 1 or 5 * g.level()
                importance = 3 + Math.ceil(f.value() / divisor)
                importance = importance > 140 and 140 or importance
                game.vm.addInfo([
                    'You\'ve caught a ',
                    caught.vm.getItemView.apply(f)
                ], importance)
                g.caught().push f
            else
                game.vm.addInfo 'Nothing was caught', 2

        actions = {fish : fish, left : move, right : move}

        get(urls[action]).then actions[action], -> m.route '/end'

    inGame: ->
        @game != null

    getWaterClass: (i, j) ->
        if i < @game.map()[0][j]
            if j != @game.position() or @game.cues()[i][0] + 1 < 0.001
                'dark-water'
            else
                cue = @game.cues()[i][0]
                cue = 9 if cue > 9
                "light-water.fish-#{cue}"
        else
            'ground'

    # add info text and animate, depending on importance
    addInfo: (text, importance) ->
        @info '.'
        value = @game.valCaught(); @game.valCaught '?'
        maxImp = importance

        end = =>
            @info text
            @game.valCaught value
            true

        timeOutF = =>
            @info ['.' for i in [0..(maxImp-importance)]]
            --importance < 0 and end() or setTimeout timeOutF, 100
            m.redraw()
        setTimeout timeOutF, 100


# --------------------------------------------------------------
# game:topBar module
# --------------------------------------------------------------
# namespace
gTopBar = {}

# view-model
gTopBar.vm = do ->
    BAR_W = 360

    timeLeftW: ->
        g = game.vm.game
        g.timeLeft() / g.totalTime() * BAR_W

    timeFullW: ->
        BAR_W - @timeLeftW()

    valueCaught: ->
        game.vm.game.valCaught()


# --------------------------------------------------------------
# game:gameActions module
# --------------------------------------------------------------
# namespace
gameActions = {}

# list of actions available in the game
gameActions.actions = -> [{
        action : 'left',
        title  : game.vm.game.position() > 0 and 'move left' or ' return home',
    }, {
        action : 'fish',
        title  : 'fish here',
    }, {
        action : 'right',
        title  : 'move right',
    }
]



# --------------------------------------------------------------
# game:infoArea module
# --------------------------------------------------------------
# namespace
infoArea = {}

# classes for different level of cue detail
infoArea.cues = [
    'none',
    'fa-map-marker',
    'fa-camera-retro',
    'fa-volume-up',
    'fa-wifi',
    'fa-user'
]

# classes for different lines
infoArea.lines = ['none', 'fa-angle-left', 'fa-angle-double-left']


# --------------------------------------------------------------
# game:gameMap module
# --------------------------------------------------------------
# namespace
gameMap = {}

# tile width
gameMap.TILE_W = 40


# --------------------------------------------------------------
# caught module
# --------------------------------------------------------------
# namespace
caught = {}

# view-model
caught.vm = do ->
    getItemView: -> [
        m('div.fish-img', {class: @name()})
        m('span', @name())
        ', weight '
        @weight()
        ' kg, value '
        m('strong', {title: 'Coins you\'ve earned'}, @value())
    ]
    compare: (a, b) ->
        b.value() - a.value()


# --------------------------------------------------------------
# end of game module
# --------------------------------------------------------------
# namespace
end = {}


# --------------------------------------------------------------
# shop module
# --------------------------------------------------------------
# namespace
shop = {}

# class for all types of updates
class shop.Update
    constructor: (b, type) ->
        @name = m.prop b.name
        @cost = m.prop b.cost
        @perk = m.prop b.perk
        @type = m.prop type

# model to store all updates
shop.Updates = Array

# view-model
shop.vm = do ->
    init: ->
        get('/v2/player').then (r) =>
            @player = new game.Player(r.player)

        @boats = new shop.Updates()
        @lines = new shop.Updates()
        @cues  = new shop.Updates()

        get('/v2/shop').then (r) =>
            for u in r.boats
                @boats.push new shop.Update u, 'boats'
            for u in r.lines
                @lines.push new shop.Update u, 'lines'
            for u in r.cues
                @cues.push new shop.Update u, 'cues'

    currentBoat: -> shop.vm.boats[shop.vm.player.boat() + 1]
    updateBoat: -> shop.vm.boats[shop.vm.player.boat() + 2]
    currentLine: -> shop.vm.lines[shop.vm.player.line() + 1]
    updateLine: -> shop.vm.lines[shop.vm.player.line() + 2]
    currentCue: -> shop.vm.cues[shop.vm.player.cue() + 1]
    updateCue: -> shop.vm.cues[shop.vm.player.cue() + 2]

    update: ->
        get('/update/' + @type()).then -> m.route '/shop'


# --------------------------------------------------------------
# trophies module
# --------------------------------------------------------------
# namespace
trophies = {}

# a model for storing a list of trophies
# which for now will all be fish
trophies.Trophies = Array

# view-model
trophies.vm = do ->
    init: ->
        get('/v2/player').then (r) =>
            @player = new game.Player(r.player)

        @userT = new trophies.Trophies()
        @gameT = new trophies.Trophies()

        get('/v2/trophies').then (r) =>
            for t, i in r.userTrophies
                if t.value > 0
                    @userT.push new game.Fish t
                    @gameT.push new game.Fish r.gameTrophies[i]
            @userT.sort (a, b) -> a.name() > b.name()
            @gameT.sort (a, b) -> a.name() > b.name()


# controller
nav.controller = ->
    links: nav.LinkList()


# controller
class loading.controller
    constructor: ->
        loading.vm.init()


# controller
home.controller = ->
    home.vm.init()
    game.vm.init().then ->
        if game.vm.inGame()
            m.route('/game')



# controller
class game.controller
    constructor: ->
        game.vm.init()


# controller
caught.controller = ->
    game.vm.init()


# controller
class end.controller
    constructor: ->
        get('/end').then (r) =>
            @earned  = m.prop r.earned
            @maximum = m.prop r.maximum
            @avg     = m.prop r.avg
            @money   = m.prop r.money
            @stars   = m.prop r.stars


# controller
shop.controller = ->
    shop.vm.init()


# controller
trophies.controller = ->
    trophies.vm.init()


# view
nav.view = (ctrl) -> [
    ctrl.links().map((link) ->
        m('a', {href: link.url, config: m.route}, link.title))
]


# view
loading.view = (ctrl) ->
    (loading.vm.loading() and m('div', [
        m('span.fa.fa-spin.fa-spinner', ' ')
        ' Loading...'
    ]) or '')


# view
home.view = -> [
    topBar('Choose a location:', game.vm.player.money())
    m('h2', [
        'Location'
        m('.right', 'High Score')
    ])
    list.view(home.vm.levels, home.vm.getItemView)
]


# view
game.view = (ctrl) -> [
    gTopBar.view()
    gameActions.view()
    infoArea.view()
    gameMap.view()
]


# Day sub-view
gTopBar.daySW = -> m('.day-ind', [
    'Day '
    m('span', game.vm.game.day())
    '. '
    m('span', game.vm.game.name())
])

# time sub-view
gTopBar.timeSW = -> [
    m('i.fa.fa-clock-o')
    m('span.time-indicator.time-left',
        {style: {width: gTopBar.vm.timeLeftW()+'px'}}, m.trust '&nbsp;')
    m('span.time-indicator.time-full',
        {style: {width: gTopBar.vm.timeFullW()+'px'}}, m.trust '&nbsp;')
]

# money sub-view
gTopBar.moneySW = -> m('div.right.money-ind', [
    '+'
    m('span', {}, gTopBar.vm.valueCaught())
    ' coins'
])

# view
gTopBar.view = (caught) -> m('div.top-bar', [
    gTopBar.timeSW()
    gTopBar.daySW()
    (caught and m('a.right[href=/game]', {config: m.route}, 'Back') or m('a.right[href=/caught]', {config: m.route}, "Caught #{game.vm.game.caught().length} fish"))
    gTopBar.moneySW()
])


# view
gameActions.view = -> [
    m('div#game-actions', [
        gameActions.actions().map((action) ->
            m('a[href="#"]', {onclick: link game.vm.act.bind(@, action.action)},
                action.title))])
]


# view
infoArea.view = -> m('div#info-area', [
    game.vm.info()
    m('div.right.fa', {
        class: infoArea.cues[game.vm.player.cue() + 1]
        title: game.vm.player.cueN()
    })
    m('div.right.fa', {
        class: infoArea.lines[game.vm.player.line() + 1]
        title: game.vm.player.lineN()
    })
])


# a sub view for displaying boat
gameMap.boatSW = -> m('p', [
    m('span.boat-' + game.vm.player.boat(), {style:
        {marginLeft: gameMap.TILE_W * game.vm.game.position() + 'px'}})
])

# a sub-view for displaying actual water depth map
gameMap.waterSW = ->
    if game.vm.game.showDepth()
        [m('p', [m('span.' + game.vm.getWaterClass(i, j)) for j in [0...20]]) for i in [0...10]]
    else
        [m('span.dark-water') for i in [0...20]]

# view
gameMap.view = -> m('div#game-map', [
    gameMap.boatSW()
    gameMap.waterSW()
])


# view
caught.view = -> [
    gTopBar.view(true)
    list.view(game.vm.game.caught().sort(caught.vm.compare), caught.vm.getItemView)
]


# view
end.view = (c) -> [
    m('div.top-bar.large', [
        'This day is over!'
    ])
    m('ul.list', [
        m('li', [
            'Earned '
            m('strong', c.earned())
            ' coins out of '
            m('strong', c.maximum())
            ' possible in this go.'
        ])
        m('li', [
            'Now you have '
            m('strong', c.money())
            ' coins.'
        ])
    ])
]


# a sub-view to display current level of update
shop.currentView = (u) -> m('div.shop-item', [
    'You have a '
    m('span', u.name())
    ': '
    m.trust u.perk()
])

# a sub-view to display new level of update
shop.updateView = (u) ->
    if not u
        m('div.shop-item', 'Nothing is better!')
    else if shop.vm.player.money() < u.cost()
        m('div.shop-item', [
            'Upgrade to '
            m('span', u.name())
            ' for '
            m('strong', {title: 'Cost in coins'}, u.cost())
            ': '
            m.trust u.perk()
        ])
    else
        m('div.shop-item', [
            'Upgrade to '
            m('a[href=#]', {onclick: link shop.vm.update.bind u}, u.name())
            ' for '
            m('strong', {title: 'Cost in coins'}, u.cost())
            ' coins: '
            m.trust u.perk()
        ])

# view
shop.view = -> [
    topBar('Shop:', shop.vm.player.money())
    m('h2', 'Boats')
    shop.currentView(shop.vm.currentBoat())
    shop.updateView(shop.vm.updateBoat())
    m('h2', 'Lines')
    shop.currentView(shop.vm.currentLine())
    shop.updateView(shop.vm.updateLine())
    m('h2', 'Cues')
    shop.currentView(shop.vm.currentCue())
    shop.updateView(shop.vm.updateCue())
]


# sub-view to show single trophy item
trophies.item = (userT, gameT) -> m('li', [
    caught.vm.getItemView.apply(userT)
    m('.right', [
        '/ '
        m('strong', {title: 'High Score'}, gameT.value())
    ])
])

# sub-view to list all trophies
trophies.listTrophies = ->
    if @userT.length > 0
        m('.list', [trophies.item(@userT[i], @gameT[i]) for i in [0...@userT.length]])
    else
        'You have not caught any trophies yet'

# view
trophies.view = -> [
    topBar('Trophies and records:', trophies.vm.player.money())
    m('h2', [
        'Your trophy'
        m('.right', 'Global High Score')
    ])
    trophies.listTrophies.apply(trophies.vm)
]


# --------------------------------------------------------------
# main script
# --------------------------------------------------------------
# load up navigation
m.module document.getElementById('nav'), nav

# load up loading overlay
m.module document.getElementById('loading'), loading

# --------------------------------------------------------------
# routing
# --------------------------------------------------------------
m.route.mode = 'hash'
m.route document.getElementById('page'), '/', {
    '/'         : home,
    '/game'     : game,
    '/caught'   : caught,
    '/end'      : end,
    '/shop'     : shop,
    '/trophies' : trophies
}

