angular.module('tomato.directives', ['tomato.services']).
  directive('appVersion', [
    'version'
    (version) ->
      (scope, elm, attrs) ->
        elm.text(version)
  ])
