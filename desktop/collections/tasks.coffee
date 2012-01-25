class exports.Tasks extends Backbone.Collection
  model: require('models/task').Task

  done: =>
    @filter (task) -> task.isFinished()

  remaining: =>
    @without.apply @, @done()

  nextOrder: =>
    return 0 if not @length
    1 + _.max @pluck 'order'

  comparator: (task) ->
    [
      task.isFinished()
      task.get 'order'
    ]
