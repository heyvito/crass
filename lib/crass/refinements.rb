# frozen_string_literal: true

module Crass
  module Refinements
    PLUS_MINUS = ['+', '-'].freeze

    refine String do
      def self.helper(name, &block)
        define_method(name, &block)
      end

      helper(:uni) { unpack1("U") }
      helper(:between?) { |a, b| uni >= a && uni <= b }
      helper(:digit?) { between? 0x30, 0x39 }
      helper(:hex?) { digit? || between?(0x41, 0x46) || between?(0x61, 0x66) }
      helper(:uppercase?) { between? 0x41, 0x5a }
      helper(:lowercase?) { between? 0x61, 0x7a }
      helper(:letter?) { uppercase? || lowercase? }
      def name_char?
        digit? || name_start? || uni == 0x2d
      end

      def name_start?
        letter? || uni == 0x5f || between?(0x0080, 0x10ffff)
      end

      def plus_minus? = PLUS_MINUS.include?(self)

      def non_printable?
        between?(0x0, 0x08) ||
        between?(0x0e, 0x1f) ||
        uni == 0x0b ||
        uni == 0x7f
      end

      def non_ascii?
        uni == 0xb7 ||
          between?(0xc0, 0xd6) ||
          between?(0xd8, 0xf6) ||
          between?(0xf8, 0x37d) ||
          between?(0x37f, 0x1fff) ||
          uni == 0x200c ||
          uni == 0x200d ||
          uni == 0x203f ||
          uni == 0x2040 ||
          between?(0x2070, 0x218f) ||
          between?(0x2c00, 0x2fef) ||
          between?(0x3001, 0xd7ff) ||
          between?(0xf900, 0xfdcf) ||
          between?(0xfdf0, 0xfffd) ||
          uni >= 0x10000
      end

      helper(:ident_start?) { letter? || non_ascii? || uni == 0x5f }
      helper(:ident_char?) { ident_start? || digit? || uni == 0x2d }
      helper(:newline?) { uni == 0xa }
      helper(:whitespace?) { newline? || uni == 0x9 || uni == 0x20 }
      helper(:bad_escape?) { newline? }
      helper(:surrogate?) { between?(0xd800, 0xdfff) }
    end
  end
end
