# underscore template
# =======================================================================
_.templateSettings =
	interpolate: /\{\{\=(.+?)\}\}/g
	escape: /\{\{\-(.+?)\}\}/g
	evaluate: /\{\{(.+?)\}\}/g

# Add Widget (modal)
# =======================================================================
class AddWidgetView extends Backbone.View
	el: $("#addWidgetModal")
	events:
		"click #addWidget"					: "addWidget"
		"click #testWidget"					: "testWidget"
		"click .sample-feed-list a"	: "selectSample"
	tmpModel: null
	tmpView: null
	initialize: ->
		sampleFeedsTmpl = _.template $("#sampleFeedsTemplate").html()
		$("#sampleFeeds").html sampleFeedsTmpl(groups: SampleFeedGroups)
	selectSample: (e) ->
		e.preventDefault()
		$("#addWidgetUrl").val e.target.href
		$("#testWidget").trigger "click"
	testWidget: =>
		@tmpModel = WidgetModel.create($("#addWidgetUrl").val())
		@tmpView = new WidgetView(model: @tmpModel)
		$("#testArea").html(@tmpView.render().el)
		@tmpModel.loadEntries(true)
	addWidget: =>
		return unless @tmpModel
		$tabContent = $("#tabContents .active")
		tabId = $tabContent.prop("id")
		@tmpModel.set(tabId: tabId)

		for model in WidgetList.instance.where(tabId: tabId, column: 0)
			model.save(row: model.get("row") + 1)
		WidgetList.instance.add(@tmpModel)
		@tmpModel.save()
		@tmpModel = null

		$tabContent.find(".column:eq(0)").prepend(@tmpView.el)
		@tmpView = null
		$("#addWidgetModal").modal("hide")
		$("#addWidgetUrl").val("")

# Widget 
# =======================================================================
class WidgetView extends Backbone.View
	tagName: "div"
	className: "widget"
	tmpl: _.template($("#widgetTemplate").html())
	events:
		"dblclick .widget-header"	: "toggleCollapsed"
		"click .refresh"					: "refresh"
		"click .settings, .cancel": "toggleSettings"
		"click .save"							: "save"
		"click .delete"						: "delete"
		"click .pager a"					: "movePage"
	initialize: ->
		@model.on "change", @render
		@model.on "destroy", @remove, @
	render: (loadingEntries = false) =>
		@$el.prop("id", @model.id).html(@tmpl(@model.toJSON()))
		@model.loadEntries() if loadingEntries
		@
	toggleCollapsed: =>
		$bodies = @$el.find(".panel-body")
		@model.save(collapsed: $bodies.is(":visible"))
	refresh: (e) =>
		e.stopPropagation()
		@render(true)
	toggleSettings: (e) =>
		e.stopPropagation()
		$settings = @$(".widget-settings")
		if $settings.is(":visible")
			$settings.slideUp(300)
		else
			@$("input[name=title]").val(@model.get("title"))
			@$("input[name=url]").val(@model.get("url"))
			@$("select[name=num]").val(@model.get("num"))
			@$("select[name=color]").val(@model.get("color"))

			$selectTab = @$("select[name=tabId]").empty()
			for tab in TabList.instance.models
				$("<option />")
					.attr("value", tab.id)
					.text(tab.get("title"))
					.appendTo($selectTab)
			$selectTab.val(@model.get("tabId"))

			$settings.slideDown(300)
	save: =>
		@$(".widget-settings").slideUp(300, =>
			changes = 
				title	: @$("input[name=title]").val()
				url		: @$("input[name=url]").val()
				num 	: parseInt(@$("select[name=num]").val(), 10)
				color	: @$("select[name=color]").val()
				tabId : @$("select[name=tabId]").val()
			if changes.tabId != @model.get("tabId")
				changes.col = 0
				changes.row = 0
				for model in WidgetList.instance.where(tabId: changes.tabId, column: 0)
					model.save(row: model.get("row") + 1)
				@$el.fadeOut(200, ->
					$(@).prependTo("##{changes.tabId} .column:eq(0)").delay(10).show()
				)

			@model.save(changes)
		)
	delete: =>
		if confirm("do you really delete \"#{@model.get("title")}\" widget ?")
			@model.destroy()
	movePage: (e) =>
		return if $(e.target).closest("li").hasClass("disabled")
		$list = @$(".feeds li")
		oldPage = Number($list.filter(":visible").hide().data("page"))
		inc = if $(e.target).text() == "Next" then 1 else -1
		curPage = oldPage + inc
		hasPrev = $list.is("[data-page=#{curPage - 1}]")
		hasNext = $list.is("[data-page=#{curPage + 1}]")

		$list.filter("[data-page=#{curPage}]").show()
		@$(".previous-page").toggleClass("disabled", !hasPrev)
		@$(".next-page").toggleClass("disabled", !hasNext)

# Search
# =======================================================================
class SearchView extends Backbone.View
	el: $("#searchText")
	initialize: ->
		$("a.query").click (e) =>
			e.target.href += encodeURIComponent(@$el.val())

		callbacks = []
		$head = $("head")
		$suggest = null
		baseUrl = "http://suggestqueries.google.com/complete/search?hl=ja&client=firefox&callback=completeCallback&q="

		@$el.suggest
			classSuggest: "suggest"
			topDiff: 18
			onSearch: (word, callback) =>
				$suggest ?= $(".suggest")
				$suggest.width(@$el.width() + 24)
				$("<script type='text/javascript' />")
					.attr("src", baseUrl + @$el.val())
					.appendTo($head)
				callbacks.push(callback)
			onSelect: (word) =>
				@$el.closest("form").submit()

		window.completeCallback = (data) ->
			callback = callbacks.shift()
			callback && callback(data[1])

# Tab Container
# =======================================================================
class TabContainerView extends Backbone.View
	el: $("#tabContainer")
	events:
		"click #createTab": "createTab"
	initialize: ->
		TabList.instance.on("add", @addTab)
		# WidgetList.instance.on("add", @addWidget)
		# WidgetList.instance.on("remove", @removeWidget)

		@$("#tabTitles").sortable
			items: "li.title"
			cursor: "move"
			opacity: 0.7
			revert: 200
			stop: (e, ui) =>
				@$("li.title").each ->
					$v = $(this)
					id = $v.find("a").attr("href").replace("#", "")
					m = TabList.instance.get(id)
					m.save(order: $v.index())

		for model in TabList.instance.models
			@$("#tabTitles li:last").before(new TabTitleView(model: model).render().el)
			@$("#tabContents").append(new TabContentView(model: model).render().el)

		@$el.show()
	createTab: ->
		title = prompt("input tab title.", "")
		return unless title?.length > 0
		model = TabModel.create(title)
		TabList.instance.add(model)
		model.save()
	addTab: (model) ->
		new TabContentView(model: model)
			.render()
			.$el
			.appendTo("#tabContents")
		new TabTitleView(model: model)
			.render()
			.$el
			.bind("click.bs.tab.data-api", (e) ->
				e.preventDefault()
				$(@).tab("show")
			)
    	.insertBefore("#tabTitles li:last")

# Tab Title
# =======================================================================
class TabTitleView extends Backbone.View
	tagName: "li"
	className: "title"
	tmpl: _.template($("#tabTitleTemplate").html())
	events:
		"dblclick a"				: "rename"
		"click button.close": "delete"
	initialize: ->
		@model.on "change:title", @render
		@model.on "destroy", @remove, @
	render: =>
		@$el
			.toggleClass("active", @model.get("active"))
			.html(@tmpl(@model.toJSON()))
		@
	rename: (e) =>
		#e.preventDefault()

		title = prompt("change tab title.", @model.get("title"))
		return unless title?.length > 0
		TabList.instance
			.where(active: true)
			.forEach((m) -> m.set(active: false))
		@model.set(title: title, active: true)
		@model.save()
	delete: (e) =>
		e.stopPropagation()
		e.preventDefault()
		if confirm("do you really delete \"#{@model.get("title")}\" tab ?")
			WidgetList.instance
			 	.where(tabId: @model.id)
			 	.forEach((m) -> m.destroy())
			@model.destroy()

# Tab Content
# =======================================================================
class TabContentView extends Backbone.View
	tagName: "div"
	className: "row tab-pane"
	tmpl: _.template($("#tabContentTemplate").html())
	initialize: ->
		@model.on "destroy", @remove, @
	render: =>
		@$el
			.prop("id", @model.id)
			.toggleClass("active", @model.get("active"))
			.html(@tmpl(@model.toJSON()))

		@$(".column").sortable
			items: ".widget"
			handle: ".widget-header"
			cursor: "move"
			connectWith: ".column"
			placeholder: "widget-placeholder"
			forcePlaceholderSize: true
			opacity: 0.7
			revert: 200
			stop: (e, ui) =>
				@$(".widget").each ->
					$v = $(this)
					m = WidgetList.instance.get($v.prop("id"))
					m.save
						row: $v.index()
						column: $v.closest(".column-wrapper").index()

		for model in WidgetList.instance.where(tabId: @model.id)
			view = new WidgetView model: model
			@$(".column:eq(#{model.get("column")})")
				.append(view.render(true).el)
		@

# App 
# =======================================================================
class AppView extends Backbone.View
	el: "body"
	initialize: ->
		if document.cookie.indexOf("_ore_no_igoogle_session") == -1
			@_init(null)
		else
			$.ajax
				url: "/user"
				success: (user) => @_init(user)
				error: (jqXHR, textStatus) =>
					@_init(null)
					console.log(jqXHR, textStatus)
					alert("sorry, something wrong...")
	_init: (user) =>
		State.loggedIn = user?
		State.authToken = user && user.token

		info = user?.info || SampleInfo
		WidgetList.instance = new WidgetList(info.widgets)
		TabList.instance = new TabList(info.tabs)
		TabList.instance.forEach((m, index) -> m.set(active: index == 0))

		setTimeout(->
			$("#loading").hide()
			if State.loggedIn
				$("#topExplain").hide()
			else
				$("#topExplain").css("visibility", "visible")
			
			navTmpl = _.template($("#navbar-right-template").html())
			$(".navbar-collapse").append(navTmpl(loggedIn: State.loggedIn))

			new SearchView
			new AddWidgetView
			new TabContainerView
		, 300)
		

# run
# =======================================================================
new AppView
