Components.utils.import('resource://gre/modules/Services.jsm')

Zotero.ReportCustomizer =
  parser: Components.classes['@mozilla.org/xmlextras/domparser;1'].createInstance(Components.interfaces.nsIDOMParser)
  serializer: Components.classes['@mozilla.org/xmlextras/xmlserializer;1'].createInstance(Components.interfaces.nsIDOMSerializer)
  document: Components.classes["@mozilla.org/xul/xul-document;1"].getService(Components.interfaces.nsIDOMDocument)

  set: (key, value) ->
    return Zotero.Prefs.set("report-customizer.#{key}", value)

  get: (key) ->
    try
      return Zotero.Prefs.get("report-customizer.#{key}")
    catch
      return null

  show: (key, visible) ->
    if typeof visible == 'undefined' # get state
      try
        return not @get("remove.#{key}")
      return true

    # set state
    @set("remove.#{key}", not visible)
    return visible

  openPreferenceWindow: (paneID, action) ->
    io = {
      pane: paneID
      action: action
    }
    window.openDialog(
      'chrome://zotero-report-customizer/content/options.xul',
      'zotero-report-customizer-options',
      'chrome,titlebar,toolbar,centerscreen' + (if Zotero.Prefs.get('browser.preferences.instantApply', true) then 'dialog=no' else 'modal'),
      io
    )
    return

  label: (name) ->
    @labels ?= Object.create(null)
    @labels[name] ?= {
      name: name
      label: Zotero.getString("itemFields.#{name}")
    }
    return @labels[name]

  addField: (type, field) ->
    type.fields.push(field)
    @fields[field.name] = true
    return

  log: (msg...) ->
    msg = for m in msg
      switch
        when (typeof m) in ['string', 'number'] then '' + m
        when Array.isArray(m) then JSON.stringify(m)
        when m instanceof Error and m.name then "#{m.name}: #{m.message} \n(#{m.fileName}, #{m.lineNumber})\n#{m.stack}"
        when m instanceof Error then "#{e}\n#{e.stack}"
        else JSON.stringify(m)

    Zotero.debug("[report-customizer] #{msg.join(' ')}")
    return

  init: ->
    # Load in the localization stringbundle for use by getString(name)
    @localizedStringBundle = Services.strings.createBundle('chrome://zotero-report-customizer/locale/zotero-report-customizer.properties', Services.locale.getApplicationLocale())
    Zotero.ItemFields.getLocalizedString = ((original) ->
      return (itemType, field) ->
        try
          return Zotero.ReportCustomizer.localizedStringBundle.GetStringFromName('itemFields.citekey') if field == 'citekey'
        # pass to original for consistent error messages
        return original.apply(this, arguments)
    )(Zotero.ItemFields.getLocalizedString)

    # monkey-patch Zotero.getString to supply new translations
    Zotero.getString = ((original) ->
      return (name, params) ->
        try
          return Zotero.ReportCustomizer.localizedStringBundle.GetStringFromName(name)  if name == 'itemFields.citekey'
        # pass to original for consistent error messages
        return original.apply(this, arguments)
    )(Zotero.getString)

    @tree = []
    @fields = {}
    collation = Zotero.getLocaleCollation()

    for type in Zotero.ItemTypes.getPrimaryTypes().concat(Zotero.ItemTypes.getSecondaryTypes(), Zotero.ItemTypes.getHiddenTypes())
      @tree.push({
        id: type.id
        name: type.name
        label: Zotero.ItemTypes.getLocalizedString(type.id)
      })
    @tree.sort((a, b) -> collation.compareString(1, a.label, b.label))

    for type in @tree
      type.fields = []
      @addField(type, @label('itemType'))

      # getItemTypeFields yields an iterator, not an arry, so we can't just add them
      @addField(type, @label(Zotero.ItemFields.getName(field))) for field in Zotero.ItemFields.getItemTypeFields(type.id)
      @addField(type, @label('citekey')) if Zotero.BetterBibTex
      @addField(type, @label('tags'))
      @addField(type, @label('attachments'))
      @addField(type, @label('related'))
      @addField(type, @label('notes'))
      @addField(type, @label('dateAdded'))
      @addField(type, @label('dateModified'))
      @addField(type, @label('accessDate'))
      @addField(type, @label('extra'))
    @fields = Object.keys(@fields)


    return

class Zotero.ReportCustomizer.XmlNode
  constructor: (@namespace, @root, @doc) ->
    if !@doc
      @doc = Zotero.ReportCustomizer.document.implementation.createDocument(@namespace, @root, null)
      @root = @doc.documentElement

  serialize: -> Zotero.ReportCustomizer.serializer.serializeToString(@doc)

  alias: (names) ->
    for name in names
      @Node::[name] = do (name) -> (v...) -> XmlNode::add.apply(@, [{"#{name}": v[0]}].concat(v.slice(1)))
    return

  set: (node, attrs...) ->
    for attr in attrs
      for own name, value of attr
        switch
          when typeof value == 'function'
            value.call(new @Node(@namespace, node, @doc))

          when name == ''
            node.appendChild(@doc.createTextNode('' + value))

          else
            if Zotero.ReportCustomizer.get('debugging')
              Zotero.debug("Adding attribute: #{JSON.stringify(name)}")
            node.setAttribute(name, '' + value)
    return

  add: (content...) ->
    if typeof content[0] == 'object'
      for own name, attrs of content[0]
        continue if name == ''
        node = @doc.createElementNS(@namespace, name)
        @root.appendChild(node)
        content = [attrs].concat(content.slice(1))
        break # there really should only be one pair here!
    node ?= @root

    content = (c for c in content when typeof c == 'number' || c)

    for attrs in content
      switch
        when typeof attrs == 'string'
          node.appendChild(@doc.createTextNode(attrs))

        when typeof attrs == 'function'
          attrs.call(new @Node(@namespace, node, @doc))

        when attrs.appendChild
          node.appendChild(attrs)

        else
          @set(node, attrs)

    return

# Initialize the utility
window.addEventListener('load', ((e) ->
  Zotero.ReportCustomizer.init()
  return
), false)
