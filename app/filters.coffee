F = angular.module 'tomato.filters', []

F.filter 'interpolate', [
  'version',
  (version) ->
    (text) ->
      String(text).replace(/\%VERSION\%/mg, version)
]
