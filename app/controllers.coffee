TomatoCtrl = ($scope, Tomato, Task, Break, Work) ->
  $scope.tomato = Tomato.get()
  $scope.tasks = Task.query()

  $scope.breaks = Break.query ->
    for brake in $scope.breaks
      continue if brake.updatedAt > brake.createdAt
      showBreakTimer brake
      break

  $scope.works = Work.query ->
    workSec = 60 * $scope.tomato.workMin
    post = new Date(new Date().getTime() - 1000 * workSec)
    for work in $scope.works
      continue unless work.createdAt is work.updatedAt
      start = new Date(work.createdAt)
      if start > post
        showWorkTimer work
        break

  $scope.ui =
    filter: ''
    order: (t) -> "#{t.finishedAt}-#{9 - t.priority}-#{t.name}"
    edit: false
    task: new Task(name: '', priority: 0, difficulty: 0)
    brake: new Break(name: 'quick')

  $scope.timer =
    clock: 0
    name: null
    work: null
    brake: null

  $scope.editTomato = ->
    $scope.ui.edit = not $scope.ui.edit
    if $scope.ui.edit
      $('#slug').select()

  $scope.updateTomato = ->
    Tomato.save $scope.tomato, (t) ->
      [_, p, _, s] = window.location.href.match /^(.+?)\/([^\/]+)\/(\#.+)$/
      url = "#{p}/#{$scope.tomato.slug}/"
      window.location.href = if s then "#{url}#{s}" else url
      $scope.ui.edit = false

  $scope.removeTomato = ->
    Tomato.remove $scope.tomato, (t) ->
      [_, p, _, _] = window.location.href.match /^(.+?)\/([^\/]+)\/(\#.+)$/
      window.location.href = p

  $scope.addTask = ->
    return if $scope.ui.task.name is ''
    Task.save $scope.ui.task, (task) ->
      $scope.tasks.push task
      $scope.ui.task = new Task(name: '', priority: 0, difficulty: 0)
      $('#cr').select()

  $scope.flagTask = (taskId) ->
    for task, i in $scope.tasks
      continue unless task.id is taskId
      break if task.finishedAt > task.createdAt
      task.priority = if task.priority is 0 then 1 else 0
      task.$save taskId: task.id
      break

  $scope.removeTask = (taskId) ->
    for task, i in $scope.tasks
      continue unless task.id is taskId
      break if task.finishedAt > task.createdAt
      task.$remove taskId: task.id, -> $scope.tasks.splice i, 1
      break

  $scope.startTask = (taskId) ->
    for task in $scope.tasks
      continue unless task.id is taskId
      break if task.finishedAt > task.createdAt
      work = new Work()
      work.$save taskId: task.id, ->
        task.$save taskId: task.id
        showWorkTimer work
      break

  $scope.finishTask = (taskId) ->
    for task in $scope.tasks
      continue unless task.id is taskId
      task.finishedAt = if task.finishedAt < task.createdAt then new Date() else new Date(0)
      task.$save taskId: task.id
      break

  $scope.worksFor = (taskId) ->
    (w for w in $scope.works when w.taskId is taskId)

  $scope.startBreak = ->
    Break.save $scope.ui.brake, (brake) ->
      $scope.ui.brake = new Break(name: 'quick')
      $scope.timer = clock: 1, name: brake.name, work: null, brake: brake

  $scope.finishBreak = ->
    b = $scope.timer.brake
    b.$save breakId: b.id, ->
      $scope.timer.brake = null
      $('#timer').modal('hide')

  showWorkTimer = (work) ->
    dt = $scope.tomato.workMin * 60
    elapsed = new Date() - new Date(work.createdAt)
    for task in $scope.tasks
      continue unless task.id is work.taskId
      sec = Math.floor dt - elapsed / 1000
      $scope.timer = clock: sec, name: task.name, work: work, brake: null
      showTimer()
      break

  showBreakTimer = (brake) ->
    elapsed = new Date() - new Date(brake.createdAt)
    sec = Math.floor elapsed / 1000
    $scope.timer = clock: sec, name: brake.name, work: null, brake: brake
    showTimer()

  showTimer = ->
    $('#timer').modal('show').on 'hidden', ->
      w = $scope.timer.work
      w.$remove(workId: w.id, taskId: w.taskId) if w
      b = $scope.timer.brake
      b.$remove(breakId: b.id) if b
      $scope.timer = clock: 0, name: null, work: null, brake: null

  $('#cr').select()

TomatoCtrl.$inject = ['$scope', 'Tomato', 'Task', 'Break', 'Work']


angular.module('app.controllers', ['app.services'])
  .controller('TomatoCtrl', TomatoCtrl)
