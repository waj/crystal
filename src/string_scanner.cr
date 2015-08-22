# `StringScanner` provides for lexical scanning operations on a String.
#
# ### Example
#
#     require "string_scanner"
#     s = StringScanner.new("This is an example string")
#     s.eos?         # => false
#
#     s.scan(/\w+/)  # => "This"
#     s.scan(/\w+/)  # => nil
#     s.scan(/\s+/)  # => " "
#     s.scan(/\s+/)  # => nil
#     s.scan(/\w+/)  # => "is"
#     s.eos?         # => false
#
#     s.scan(/\s+/)  # => " "
#     s.scan(/\w+/)  # => "an"
#     s.scan(/\s+/)  # => " "
#     s.scan(/\w+/)  # => "example"
#     s.scan(/\s+/)  # => " "
#     s.scan(/\w+/)  # => "string"
#     s.eos?         # => true
#
#     s.scan(/\s+/)  # => nil
#     s.scan(/\w+/)  # => nil
#
# Scanning a string means remembering the position of a _scan offset_, which is
# just an index. Scanning moves the offset forward, and matches are sought
# after the offset; usually immediately after it.
#
# ### Method Categories
#
# Methods that advance the scan offset:
# * `#scan`
# * `#scan_until`
# * `#skip`
# * `#skip_until`
#
# Methods that deal with the position of the offset:
# * `#offset`
# * `#offset=`
# * `#eos?`
#
# Methods that deal with the last match
# * `#[]`
# * `#[]?`
#
# Miscellaneous methods
# * `#inspect`
# * `#string`
class StringScanner
  def initialize(@str)
    @offset = 0
    @length = @str.length
  end

  # Returns the current position of the scan offset.
  getter offset

  # Sets the position of the scan offset.
  def offset=(position : Int)
    raise IndexError.new unless position >= 0
    @offset = position
  end

  # Tries to match with `pattern` at the current position. If there's a match,
  # the scanner advances the scan offset and returns the matched string.
  # Otherwise, the scanner returns nil.
  #
  #     s = StringScanner.new("test string")
  #     s.scan(/\w+/)   # => "test"
  #     s.scan(/\w+/)   # => nil
  #     s.scan(/\s\w+/) # => " string"
  #     s.scan(/.*/)    # => nil
  def scan(pattern)
    match_and_advance(pattern, Regex::Options::ANCHORED)
  end

  # Scans the string _until_ the `pattern` is matched. Returns the substring up
  # to and including the end of the match, and advances the scan offset.
  # Returns `nil` if no match.
  #
  #     s = StringScanner.new("test string")
  #     s.scan_until(/tr/)   # => "test str"
  #     s.scan_until(/tr/)   # => nil
  #     s.scan_until(/g/)    # => "ing"
  def scan_until(pattern)
    match_and_advance(pattern, Regex::Options::None)
  end

  private def match_and_advance(pattern, options)
    match = pattern.match(@str, @offset, options)
    @last_match = match
    if match
      start = @offset
      @offset = match.end(0).to_i
      @str[start, @offset-start]
    else
      nil
    end
  end

  # Attempts to skip over the given `pattern` beginning with the scan offset.
  # In other words, the pattern is not anchored to the current scan offset.
  #
  # If there's a match, the scanner advances the scan offset, and it returns
  # the length of the skipped match. Otherwise it returns `nil` and does not
  # advance the offset.
  #
  # This method is the same as `#scan`, but without returning the matched
  # string.
  def skip(pattern)
    match = scan(pattern)
    match.length if match
  end

  # Attempts to skip _until_ the given `pattern` is found after the scan
  # offset. In other words, the pattern is not anchored to the current scan
  # offset.
  #
  # If there's a match, the scanner advances the scan offset, and it returns
  # the length of the skip. Otherwise it returns `nil` and does not advance the
  # offset.
  #
  # This method is the same as `#scan_until`, but without returning the matched
  # string.
  def skip_until(pattern)
    match = scan_until(pattern)
    match.length if match
  end

  # Returns the `n`-th subgroup in the most recent match.
  #
  # Raises an exception if there was no last match or if there is no subgroup.
  #
  #     s = StringScanner.new("Fri Dec 12 1975 14:39")
  #     regex = /(?<wday>\w+) (?<month>\w+) (?<day>\d+)/
  #     s.scan(regex)  # => "Fri Dec 12"
  #     s[0]           # => "Fri Dec 12"
  #     s[1]           # => "Fri"
  #     s[2]           # => "Dec"
  #     s[3]           # => "12"
  #     s["wday"]      # => "Fri"
  #     s["month"]     # => "Dec"
  #     s["day"]       # => "12"
  def [](n)
    @last_match.not_nil![n]
  end

  # Returns the nilable `n`-th subgroup in the most recent match.
  #
  # Returns `nil` if there was no last match or if there is no subgroup.
  #
  #     s = StringScanner.new("Fri Dec 12 1975 14:39")
  #     regex = /(?<wday>\w+) (?<month>\w+) (?<day>\d+)/
  #     s.scan(regex)  # => "Fri Dec 12"
  #     s[0]?           # => "Fri Dec 12"
  #     s[1]?           # => "Fri"
  #     s[2]?           # => "Dec"
  #     s[3]?           # => "12"
  #     s[4]?           # => nil
  #     s["wday"]?      # => "Fri"
  #     s["month"]?     # => "Dec"
  #     s["day"]?       # => "12"
  #     s["year"]?      # => nil
  #     s.scan(/more/)  # => nil
  #     s[0]?           # => nil
  def []?(n)
    @last_match.try(&.[n]?)
  end


  # Returns true if the scan offset is at the end of the string.
  #
  #     s = StringScanner.new("this is a string")
  #     s.eos?                 # => false
  #     s.scan(/(\w+\s?){4}/)  # => "this is a string"
  #     s.eos?                 # => true
  def eos?
    @offset >= @length
  end

  # Returns the string being scanned.
  def string
    @str
  end

  # Extracts a string corresponding to string[offset,`len`], without advancing
  # the scan offset.
  def peek(len)
    @str[@offset, len]
  end

  # Returns the remainder of the string after the scan offset.
  #
  #     s = StringScanner.new("this is a string")
  #     s.scan(/(\w+\s?){2}/)  # => "this is "
  #     s.rest                 # => "a string"
  def rest
    @str[@offset, @length - @offset]
  end

  # Writes a representation of the scanner.
  #
  # Includes the current position of the offset, the total size of the string,
  # and five characters near the current position.
  def inspect(io : IO)
    io << "#<StringScanner "
    io << @offset.to_s << "/" << @length.to_s
    start = Math.min( Math.max(@offset-2, 0), @length-5)
    io << " \"" << @str[start, 5] << "\" >"
  end
end
