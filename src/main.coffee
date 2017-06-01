{rx, rxt} = require 'reactive-coffee'
{bind, asyncBind, DepCell} = rx

doF = (f) -> f()

ERROR = Symbol()
FAILED = Sybmol()
LOADED = Sybmol()
LOADING = Symbol()
UNLOADED = Symbol()

recordData = (maker, argsArray, condFn, ctx) ->



class ajaxDepCell extends DepCell
  constructor: ({init, args, maker, onFail, onError, lazy}) ->
    lazy ?= true
    onFail ?= (err) -> console.error err, err.stack
    onError ?= (err) -> console.error err, err.stack

    prior = init
    _first = @_first = rx.cell true

    argsCell = rx.cell.from args

    argsArray = bind ->
      if _.isArray argsCell.get() then argsCell.get()
      else [argsCell.get()]

    rx.autoSub argsArray.onSet, rx.skipFirst => @_first.set true
    condFn = => not lazy and not @_first.get()

    cell = rx.asyncBind {state: UNLOADED, value: prior}, ->
      @record =>
        if condFn()
          p = maker.apply {}, argsArray.get()
          if p?
            @done {state: LOADING, value: prior}
            promise = Q p
            promise.then(
              (res) =>
                prior = processor res
                @done {promise, state: LOADED, value: prior}
              (error) => @done {promise, state: ERROR, value: onError error}
            ).catch(
              (error) => @done {promise, state: FAILED, value: onFail error}
            ).done()
          else
            prior = init
            @done {state: UNLOADED, value: init}
        else @done {state: UNLOADED, value: init}

    super -> cell.get().value

    @loading = bind -> cell.get().state == LOADING
    oldLoad = @loading.get
    @loading.get = ->
      rx.hideMutationWarnings -> _first.set false
      oldLoad.apply @

    @reload = -> cell.refresh()
    @loading = bind -> @_dataCell.get().state == LOADING

  getPromise: -> @_dataCell.raw().promise
  get: ->
    rx.hideMutationWarnings -> @_first.set false
    super()
  reload: -> @_dataCell.refresh()

class partialAjaxDepCell extends DepCell
  constructor: (_mainBind, {args, maker, onFail, onError}) ->
    _loaded = false
    _partialBind = new ajaxDepCell {args, maker, onFail, onError}
    super =>
      if not _loaded
        _loaded = true
        return _mainBind.get()
      else
        return _partialBind.get()
    @reload = ->
      if _loaded then _partialBind.reload()
      else _loaded = true
      c.refresh()

exports.rxUtil = rxUtil = {
  status: {ERROR, FAILED, LOADED, LOADING, UNLOADED}
  ajaxDepCell
  partialAjaxDepCell
}
