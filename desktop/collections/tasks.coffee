class exports.Tasks extends Backbone.Collection
  model: require('models/task').Task

  nextOrder: =>
    return 0 if not @length
    1 + _.max @pluck 'order'

  comparator: (task) ->
    lpad = (n, p, s) ->
      s = "#{s}"
      return ((p for i in [0...(n - s.length)]).concat [s]).join ''

    [
      if task.isFinished() then '1' else '0'
      lpad 16, '0', task.get 'order'
      task.get 'createdAt'
    ].join '-'
