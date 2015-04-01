# This anchor type stores information about a piece of text,
# described using start and end character offsets
class TextPositionAnchor extends Annotator.Anchor

  @Annotator = Annotator

  constructor: (anchoring, annotation, target,
      @start, @end, startPage, endPage,
      quote, diffHTML, diffCaseOnly) ->

    super anchoring, annotation, target,
      startPage, endPage,
      quote, diffHTML, diffCaseOnly

    # This pair of offsets is the key information,
    # upon which this anchor is based upon.
    unless @start? then throw new Error "start is required!"
    unless @end? then throw new Error "end is required!"

    @Annotator = TextPositionAnchor.Annotator

  # This is how we create a highlight out of this kind of anchor
  _getSegment: (page) ->

    # First we create the range from the stored start and end offsets
    mappings = @anchoring.document.getMappingsForCharRange @start, @end, [page]

    # Get the wanted range out of the response
    realRange = mappings.sections[page].realRange

    # Get a BrowserRange
    browserRange = new @Annotator.Range.BrowserRange realRange

    # Get a NormalizedRange
    normedRange = browserRange.normalize @anchoring.annotator.wrapper[0]

    type: "magic range"
    data: normedRange

# Annotator plugin for text position-based anchoring
class Annotator.Plugin.TextPosition extends Annotator.Plugin

  pluginInit: ->

    @Annotator = Annotator

    @anchoring = @annotator.anchoring

    # Register the creator for text quote selectors
    @anchoring.selectorCreators.push
      name: "TextPositionSelector"
      describe: @_getTextPositionSelector

    @anchoring.strategies.push
      # Position-based strategy. (The quote is verified.)
      # This can handle document structure changes,
      # but not the content changes.
      name: "position"
      code: @createFromPositionSelector

    # Export the anchor type
    @Annotator.TextPositionAnchor = TextPositionAnchor

  # Create a TextPositionSelector around a range
  _getTextPositionSelector: (selection) =>
    # We only care about "text range" selections.
    return [] unless selection.type is "text range"

    document = @anchoring.document

    # We need dom-text-mapper - style functionality
    return [] unless document.getStartPosForNode?

    startOffset = document.getStartPosForNode selection.range.start
    endOffset = document.getEndPosForNode selection.range.end

    if startOffset? and endOffset?
      [
        type: "TextPositionSelector"
        start: startOffset
        end: endOffset
      ]
    else
      # It looks like we can't determine the start and end offsets.
      # That means no valid TextPosition selector can be generated from this.
      unless startOffset?
        console.log "Warning: can't generate TextPosition selector, because",
          selection.range.start,
          "does not have a valid start position."
      unless endOffset?
        console.log "Warning: can't generate TextPosition selector, because",
          selection.range.end,
          "does not have a valid end position."
      [ ]

  # Create an anchor using the saved TextPositionSelector.
  # The quote is verified.
  createFromPositionSelector: (annotation, target) =>

    # We need the TextPositionSelector
    selector = @anchoring.findSelector target.selector, "TextPositionSelector"
    return unless selector?

    unless selector.start?
      console.log "Warning: 'start' field is missing from TextPositionSelector. Skipping."
      return null

    unless selector.end?
      console.log "Warning: 'end' field is missing from TextPositionSelector. Skipping."
      return null

    document = @anchoring.document

    corpus = document.getCorpus?()
    return null unless corpus

    content = corpus[selector.start ... selector.end].trim()
    currentQuote = @anchoring.normalizeString content
    savedQuote = @anchoring.getQuoteForTarget? target
    if savedQuote? and currentQuote isnt savedQuote
      # We have a saved quote, let's compare it to current content
      #console.log "Could not apply position selector" +
      #  " [#{selector.start}:#{selector.end}] to current document," +
      #  " because the quote has changed. " +
      #  "(Saved quote is '#{savedQuote}'." +
      #  " Current quote is '#{currentQuote}'.)"
      return null

    # Create a TextPositionAnchor from this data
    new TextPositionAnchor @anchoring, annotation, target,
      selector.start, selector.end,
      (document.getPageIndexForPos selector.start),
      (document.getPageIndexForPos selector.end),
      currentQuote
