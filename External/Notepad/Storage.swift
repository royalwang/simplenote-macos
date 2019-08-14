//
//  Storage.swift
//  Notepad
//
//  Created by Rudd Fawcett on 10/14/16.
//  Copyright © 2016 Rudd Fawcett. All rights reserved.
//

#if os(iOS)
    import UIKit
#elseif os(macOS)
    import AppKit
#endif

@objc
class Storage: NSTextStorage {

    /// The Theme for the Notepad
    ///
    public var theme: Theme? {
        didSet {
            let wholeRange = NSRange(location: 0, length: (self.backingString as NSString).length)

            self.beginEditing()
            self.backingStore.setAttributes([:], range: wholeRange)
            self.applyStyles(wholeRange)
            self.edited(.editedAttributes, range: wholeRange, changeInLength: 0)
            self.endEditing()
        }
    }

    /// Backing String (Cache) reference
    ///
    private var backingString = String()

    /// The underlying text storage implementation.
    ///
    var backingStore = NSMutableAttributedString(string: "", attributes: [:])

    /// Indicates if Markdown is enabled
    ///
    var markdownEnabled = false

    /// Returns the BackingString
    ///
    override var string: String {
        return backingString
    }


    /// Designated Initializer
    ///
    override init() {
        super.init()
    }

    @objc class func newInstance() -> Storage {
        let storage = Storage()
        storage.theme = Theme(markdownEnabled: false)
        return storage
    }

    override init(attributedString attrStr: NSAttributedString) {
        super.init(attributedString:attrStr)
        backingStore.setAttributedString(attrStr)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    required init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
        super.init(pasteboardPropertyList: propertyList, ofType: type)
    }

    /// Finds attributes within a given range on a String.
    ///
    /// - parameter location: How far into the String to look.
    /// - parameter range:    The range to find attributes for.
    ///
    /// - returns: The attributes on a String within a certain range.
    ///
    override func attributes(at location: Int, effectiveRange range: NSRangePointer?) -> [NSAttributedString.Key : Any] {
        return backingStore.attributes(at: location, effectiveRange: range)
    }

    /// Replaces edited characters within a certain range with a new string.
    ///
    /// - parameter range: The range to replace.
    /// - parameter str:   The new string to replace the range with.
    ///
    override func replaceCharacters(in range: NSRange, with str: String) {
        self.beginEditing()

        backingStore.replaceCharacters(in: range, with: str)
        replaceBackingStringSubrange(range, with: str)

        let change = str.utf16.count - range.length
        self.edited(.editedCharacters, range: range, changeInLength: change)
        self.endEditing()
    }

    override func replaceCharacters(in range: NSRange, with attrString: NSAttributedString) {
        self.beginEditing()
        backingStore.replaceCharacters(in: range, with: attrString)
        replaceBackingStringSubrange(range, with: attrString.string)

        let change = attrString.length - range.length
        self.edited(.editedCharacters, range: range, changeInLength: change)
        self.endEditing()
    }

    override func addAttribute(_ name: NSAttributedString.Key, value: Any, range: NSRange) {
        self.beginEditing()
        backingStore.addAttribute(name, value: value, range: range)
        self.endEditing()
    }

    override func removeAttribute(_ name: NSAttributedString.Key, range: NSRange) {
        self.beginEditing()
        backingStore.removeAttribute(name, range: range)
        self.edited(.editedAttributes, range: range, changeInLength: 0)
        self.endEditing()
    }

    /// Sets the attributes on a string for a particular range.
    ///
    /// - parameter attrs: The attributes to add to the string for the range.
    /// - parameter range: The range in which to add attributes.
    ///
    override func setAttributes(_ attrs: [NSAttributedString.Key : Any]?, range: NSRange) {
        self.beginEditing()
        backingStore.setAttributes(attrs, range: range)
        self.edited(.editedAttributes, range: range, changeInLength: 0)
        self.endEditing()
    }

    /// Processes any edits made to the text in the editor.
    ///
    override func processEditing() {
        let string = backingString
        let nsRange = string.range(from: NSMakeRange(NSMaxRange(editedRange), 0))!
        let indexRange = string.lineRange(for: nsRange)
        let extendedRange = NSUnionRange(editedRange, NSRange(indexRange, in: string))

        applyStyles(extendedRange)
        super.processEditing()
    }

    /// Applies styles to a range on the backingString.
    ///
    /// - parameter range: The range in which to apply styles.
    ///
    func applyStyles(_ range: NSRange) {
        guard let theme = self.theme else {
            return
        }

        let string = backingString
        backingStore.addAttributes(theme.body.attributes, range: range)

        for (style) in theme.styles {
            style.regex.enumerateMatches(in: string, options: .withoutAnchoringBounds, range: range, using: { (match, flags, stop) in
                guard let match = match else {
                    return
                }

                backingStore.addAttributes(style.attributes, range: match.range(at: 0))
            })
        }
    }

    @objc
    func applyStyle(markdownEnabled: Bool) {
        self.theme = Theme(markdownEnabled: markdownEnabled)
    }
}


private extension Storage {

    func replaceBackingStringSubrange(_ range: NSRange, with string: String) {
        let utf16String = backingString.utf16
        let startIndex = utf16String.index(utf16String.startIndex, offsetBy: range.location)
        let endIndex = utf16String.index(startIndex, offsetBy: range.length)
        backingString.replaceSubrange(startIndex..<endIndex, with: string)
    }
}
