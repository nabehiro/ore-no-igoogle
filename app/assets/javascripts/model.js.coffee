# State
# =======================================================================
class State
	@loggedIn: false
	@authToken: null

# Backbone sync customize
# =======================================================================
syncTimer = null
syncServer = ->
	info =
		widgets: _.map(WidgetList.instance.toJSON(), (m) ->
			c = _.clone(m)
			c.entries = null
			c
		) 
		tabs: TabList.instance.toJSON()

	$.ajax
		type: "post"
		url: "/info"
		data:
			info: JSON.stringify(info)
			authenticity_token: State.authToken
		success: (user) ->
			window.location.href = "/logout" unless user
		error: (jqXHR, textStatus) ->
			console.log(jqXHR, textStatus)
			alert("sorry, saving on server failed.")

Backbone.sync = (method, model, options) ->
	return unless State.loggedIn
	clearTimeout(syncTimer)
	syncTimer = setTimeout(syncServer, 1000)

# Widget
# =======================================================================
class WidgetModel extends Backbone.Model
	@create: (url, tabId) ->
		new WidgetModel
			id: "w#{new Date().getTime()}"
			type: "feed"
			title: "loading..."
			url: url
			color: "default"
			collapsed: false
			num: 5
			tabId: tabId
			column: 0
			row: 0
			entries: null

	loadEntries: (overrideTitle = false) ->
		feed = new google.feeds.Feed(@get("url"))
		feed.setNumEntries(30)
		feed.load (result) =>
			return if result.error

			params = _.map(result.feed.entries, (e) ->
				"url=" + encodeURIComponent(e.link)
			).join("&")

			$.ajax
				url: "http://api.b.st-hatena.com/entry.counts?#{params}"
				dataType: "jsonp"
				success: (hatebuList) =>
					now = new Date
					entries = _.map(result.feed.entries, (e) ->
						date = new Date(e.publishedDate)
						diff = now - date
						if diff < 86400000
							dateStr = "#{Math.ceil(diff / 3600000)}hours"
						else
							dateStr = "#{date.getFullYear()}/#{date.getMonth() + 1}/#{date.getDate()}"

						{
							title: e.title
							url: e.link
							snippet: e.contentSnippet
							date: dateStr
							hatebu: hatebuList[e.link]
						}
					)
					if overrideTitle
						@set(entries: entries, title: result.feed.title)
					else
						@set(entries: entries)

# Widget List
# =======================================================================
class WidgetList extends Backbone.Collection
	@instance: null
	model: WidgetModel
	comparator: (model) ->
		model.get("column") * 100 + model.get("row")

# Tab
# =======================================================================
class TabModel extends Backbone.Model
	@create: (title) ->
		new TabModel
			id: "t#{new Date().getTime()}"
			active: false
			order: TabList.instance.nextOrder()
			title: title

# Tab List
# =======================================================================
class TabList extends Backbone.Collection
	@instance: null
	model: TabModel
	nextOrder: ->
		if @length == 0 then 0 else @last().get("order")
	comparator: "order"

# exports
# =======================================================================
window.State = State
window.WidgetModel = WidgetModel
window.WidgetList = WidgetList
window.TabModel = TabModel
window.TabList = TabList

