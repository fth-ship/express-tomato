class exports.Tomato extends Backbone.Model
  url: -> "/#{@id}"

  initialize: ->
    @id = @get 'slug'
