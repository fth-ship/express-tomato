class exports.Tasks extends Backbone.Collection
  model: require('models/task').Task

  comparator: (task) ->
    lpad = (n, p, s) ->
      s = "#{s}"
      ((p for i in [0...(n - s.length)]).concat [s]).join ''

    [
      if task.isFinished() then '1' else '0'
      lpad 8, '0', task.get('order') + 1000000
      task.get 'createdAt'
    ].join ':'
