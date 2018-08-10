require 'wx'

module Wx
    TE_RIGHT = 0x0200
    TE_CENTER = 0x0100
end

class NumericTextCtrl < Wx::TextCtrl
    attr_accessor :valid_chars

    def initialize(parent, id, value="", pos=Wx::DEFAULT_POSITION, size=Wx::DEFAULT_SIZE, style=0)
        super(parent, id, value, pos, size, style | Wx::TE_RIGHT)
        caret = get_caret
        caret.hide

        evt_char() {|event| on_char(event)}
        evt_text_paste(id) {|event| on_paste(event)}
    end

    def on_char(event)
        key_code = event.get_key_code
        unless (key_code >= 0x20 && key_code <= 0x2F) or
                (key_code >= 0x3A && key_code < 0x7F)
            # punctuation
            # alpha
            event.skip
        end
    end

    def on_paste(event)
        Wx::Clipboard.open {|cb|
            data_object = Wx::TextDataObject.new
            cb.get_data(data_object)
            value = data_object.get_text
            if value =~ /^[0-9]*$/
                event.skip
            end
        }
    end
end

class AmountTextCtrl < Wx::TextCtrl
    attr_accessor :valid_chars

    def initialize(parent, id, value="0.00", pos=Wx::DEFAULT_POSITION, size=Wx::DEFAULT_SIZE, style=0)
        super(parent, id, "0.00", pos, size, style | Wx::TE_RIGHT)

        @value = ""
        evt_char() {|event| on_char(event)}
        evt_text_paste(id) {|event| on_paste(event)}
        evt_text_copy(id) {|event| on_copy(event)}
    end

    def on_char(event)
        key_code = event.get_key_code
        unless (key_code >= 0x20 && key_code <= 0x2F) or
                (key_code >= 0x3A && key_code < 0x7F) or
                (key_code == Wx::K_DELETE) or
                (key_code == Wx::K_LEFT) or
                (key_code == Wx::K_RIGHT) or
                (key_code == Wx::K_UP) or
                (key_code == Wx::K_DOWN) or 
                (key_code == Wx::K_HOME) or
                (key_code == Wx::K_END)
            # punctuation, 0x2E -> .
            # alpha
            if (key_code >= 0x30 && key_code <= 0x39)
                @value << key_code.chr unless @value.length == 0 and key_code == 0x30
                case @value.length
                when 0
                    change_value("0.00")
                when 1
                    change_value("0.0#{@value}")
                when 2
                    change_value("0.#{@value}")
                else
                    change_value("#{@value[0..-3]}.#{@value[-2..-1]}")
                end # end of case
                set_insertion_point_end()
            elsif key_code == Wx::K_BACK
                from,to = get_selection()
                from,to = to,from if from > to
                if from == to  # no selection
                    case @value.length
                    when 0
                    when 1
                        @value = ""
                        change_value("0.00")
                    when 2
                        @value = @value[0]
                        change_value("0.0#{@value}")
                    when 3
                        @value = @value[0..1]
                        change_value("0.#{@value}")
                    else
                        @value = @value[0..@value.length-2]
                        change_value("#{@value[0..-3]}.#{@value[-2..-1]}")
                    end
                    set_insertion_point_end()
                elsif from == 0 and to == get_value.length   # full selection
                    @value = ""
                    change_value("0.00")
                else
                    set_selection(0,0)
                    set_insertion_point_end()
                end
            else
                event.skip
            end
        end
    end

    def on_copy(event)
        Wx::Clipboard.open {|cb|
            data_object = Wx::TextDataObject.new
            data_object.set_text(get_value)
            cb.set_data(data_object)
        }
    end

    def on_paste(event)
        Wx::Clipboard.open {|cb|
            data_object = Wx::TextDataObject.new
            cb.get_data(data_object)
            value = data_object.get_text
            if value =~ /^[0-9]*(\.[0-9]*)*$/
                value = "%.2f" % value.to_f
                change_value(value)
                @value = "%.f" % (value.to_f * 100)
                set_insertion_point_end()
            end
        }
    end
end

