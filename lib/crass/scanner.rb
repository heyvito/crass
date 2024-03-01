# frozen_string_literal: true

require 'strscan'

module Crass

  # Similar to a StringScanner, but with extra functionality needed to tokenize
  # CSS while preserving the original text.
  class Scanner
    using Crass::Refinements

    # Current character, or `nil` if the scanner hasn't yet consumed a
    # character, or is at the end of the string.
    attr_reader :current

    # Current marker position. Use {#marked} to get the substring between
    # {#marker} and {#pos}.
    attr_accessor :marker

    # Position of the next character that will be consumed. This is a character
    # position, not a byte position, so it accounts for multi-byte characters.
    attr_accessor :pos

    # String being scanned.
    attr_reader :string

    # Creates a Scanner instance for the given _input_ string or IO instance.
    def initialize(input)
      @string = input.is_a?(IO) ? input.read : input.to_s
      @scanner = StringScanner.new(@string)
      @list = input.chars

      reset
    end

    # Consumes the next character and returns it, advancing the pointer, or
    # an empty string if the end of the string has been reached.
    def consume
      if @pos < @len
        c = @list[@pos]
        @pos += 1
        @current = c
        c
      else
        ''
      end
    end

    # Consumes the rest of the string and returns it, advancing the pointer to
    # the end of the string. Returns an empty string is the end of the string
    # has already been reached.
    def consume_rest
      result = @list[pos...]

      @current = result[-1]
      @pos = @len

      result.to_s
    end

    # Returns `true` if the end of the string has been reached, `false`
    # otherwise.
    def eos? = @pos == @len

    # Sets the marker to the position of the next character that will be
    # consumed.
    def mark
      @marker = @pos
    end

    # Returns the substring between {#marker} and {#pos}, without altering the
    # pointer.
    def marked
      if (result = @list[@marker...@pos]) && !result.empty?
        result.join('')
      else
        nil
      end
    end

    # Returns up to _length_ characters starting at the current position, but
    # doesn't consume them. The number of characters returned may be less than
    # _length_ if the end of the string is reached.
    def peek = @list[pos]

    def peek1 = @list[pos + 1]

    def peekn(len) = @list[pos...len].join('')

    # Moves the pointer back one character without changing the value of
    # {#current}. The next call to {#consume} will re-consume the current
    # character.
    def reconsume
      @pos -= 1 if @pos > 0
    end

    # Resets the pointer to the beginning of the string.
    def reset
      @current = nil
      @len = @list.length
      @marker = 0
      @pos = 0
    end

    # Tries to match _pattern_ at the current position. If it matches, the
    # matched substring will be returned and the pointer will be advanced.
    # Otherwise, `nil` will be returned.
    def scan(pattern)
      if match = @scanner.scan(pattern)
        @pos += match.size
        @current = match[-1]
      end

      match
    end

    def marking
      old_mark = @marker
      mark
      catch(:abort) do
        yield
        marked
      end
    ensure
      @marker = old_mark
    end

    def scan_digits = scan_while(&:digit?)

    def scan_hex
      marking do
        max = 6
        loop do
          break if !peek.hex? || eos? || max.zero?
          consume
          max -= 1
        end
      end
    end

    def scan_while(&delegate)
      marking do
        loop do
          p = peek
          break if p.nil? || !p.yield_self(&delegate) || eos?
          consume
        end
      end
    end

    def scan_decimal
      scan_while { _1.digit? || _1 == '.' }
    end

    def scan_number_exponent
      marking do
        return unless peek.downcase == 'e'
        consume if peek.plus_minus?
        throw :abort unless peek.digit?
        consume while peek.digit?
      end
    end

    class RevertStateError < StandardError; end

    def rollback! = raise RevertStateError

    def with_rollback
      old_pos = @pos
      old_current = @current
      old_marker = @marker

      yield
    rescue RevertStateError
      @pos = old_pos
      @current = old_current
      @marker = old_marker
      return nil
    end

    def scan_number_str
      with_rollback do
        sign = nil
        integer = nil
        fractional = nil
        exponent_sign = nil
        exponent = nil

        sign = consume if peek.plus_minus?
        integer = scan_while(&:digit?) if peek.digit?

        if peek == '.'
          consume
          fractional = scan_while(&:digit?) if peek.digit?
        end

        if peek&.downcase == 'e'
          exponent_sign = consume if peek.plus_minus?
          exponent = scan_while(&:digit?) if peek.digit?
        end

        {
          sign:,
          integer:,
          fractional:,
          exponent_sign:,
          exponent:,
        }
      end
    end

    QUOTES = ['"', "'"].freeze
    # This should prolly go to refinements, but it is working on a single
    # character. Let's keep this here for now.
    def quoted_url_start?
      if peek.strip.empty?
        QUOTES.include? peek1
      else
        QUOTES.include? peek
      end
    end

    def unicode_range_start?
      return false unless peek == '+'
      p = peek1
      p.hex? || p == '|' || p == '?'
    end

    def unicode_range_end?
      peek == '-' && peek1.hex?
    end
  end
end