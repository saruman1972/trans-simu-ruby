require 'wx'
require 'simulator'
require 'inplace_edit_listctrl'
require 'textctrl_with_validator'

module Simulator
    module Orgsim
        class UIDesc
            class UIField
                include DynamicClass
                attr_accessor :left,:top,:width,:height,:size
                def initialize
                    @left = 0
                    @top = 0
                    @width = 0
                    @height = 0
                    @size = 0
                end
                
                def left=(v)
                    @left = v.to_i
                end

                def top=(v)
                    @top = v.to_i
                end

                def width=(v)
                    @width = v.to_i
                end

                def height=(v)
                    @height = v.to_i
                end

                def size=(v)
                    @size = v.to_i
                end

            end # end of class UIField

            class UIText < UIField
                define_klass :TEXT
                attr_accessor :value

                def createWidget(parent)
                    Wx::StaticText.new(parent, -1, @value, Wx::Point.new(@left,@top), Wx::Size.new(@width,@height))
                end
            end
            
            class UIInput < UIField
                attr_accessor :name
                attr_reader :klass

                def createWidget(parent)
                    t = @klass.new(parent, -1, "", Wx::Point.new(@left,@top), Wx::Size.new(@width,@height))
                    t.set_max_length(@size)
                    t
                end
            end

            class UIStringInput < UIInput
                define_klass :STRING_INPUT

                def initialize
                    super
                    @klass = Wx::TextCtrl
                end
            end

            class UIDecimalInput < UIInput
                define_klass :DECIMAL_INPUT

                def initialize
                    super
                    @klass = NumericTextCtrl
                end
            end

            class UIAmountInput < UIInput
                define_klass :AMOUNT_INPUT

                def initialize
                    super
                    @klass = AmountTextCtrl
                end
            end



        end # end of class UIDesc

        class UIDialog < Wx::Dialog
            def initialize(parent, uiDesc, panelClass)
                super(parent, -1, "User Input", Wx::DEFAULT_POSITION, Wx::Size.new(500,400))
                sizer = Wx::BoxSizer.new(Wx::VERTICAL)

                @panel = panelClass.new(self, uiDesc)
                sizer.add(@panel, 1, Wx::ALIGN_TOP | Wx::GROW | Wx::ALL, 5)

                #        gif = Wx::Animation.new("beauty.gif")
                #        ani = Wx::AnimationCtrl.new(self, -1, gif, Wx::Point.new(100,150))#, Wx::Size.new(200,200))
                #        ani.play
                #        sizer.add(ani, 0, Wx::ALIGN_TOP | Wx::GROW | Wx::ALL, 5)

                button_sizer = Wx::StdDialogButtonSizer.new
                button_sizer.add(Wx::Button.new(self, Wx::ID_OK, "OK"))
                button_sizer.add(Wx::Button.new(self, Wx::ID_CANCEL, "CANCEL"))
                button_sizer.realize
                sizer.add(button_sizer, 0, Wx::ALIGN_BOTTOM | Wx::GROW | Wx::ALL, 5)

                #        evt_paint { on_paint }
                evt_button(Wx::ID_OK) {|event| on_ok(event)}
                set_auto_layout(true)
                set_sizer(sizer)
            end

            def on_paint
                paint { |dc| do_drawing(dc) }
            end

            def do_drawing(dc)
                dc.draw_rectangle(300,300,50,50)
            end

            def on_ok(event)
                @panel.on_ok
                event.skip
            end

            def layout
            end
        end # end of class UIDialog

        class UIBase < Wx::Panel
            include DynamicClass

            def initialize(parent, uiDesc)
                super(parent)
                @uiDesc = uiDesc
            end
        end

        class UIGeneral < UIBase
            define_klass :GENERAL

            def initialize(parent, uiDesc)
                super(parent, uiDesc)
                @inputList = uiDesc.action.userInputList

                sizer = Wx::BoxSizer.new(Wx::VERTICAL)
                @lstCtrl = InplaceEditListCtrl.new(self)
                layoutFields(@lstCtrl)
                sizer.add(@lstCtrl, 1, Wx::ALIGN_CENTER | Wx::GROW | Wx::ALL)

                set_auto_layout(true)
                set_sizer(sizer)
            end

            def layoutFields(lstCtrl)
                lstCtrl.insert_column(0, "Field Name")
                lstCtrl.insert_column(1, "Description")
                lstCtrl.set_column_width(1, 160)
                lstCtrl.insert_column(2, "Value")
                lstCtrl.set_column_width(2, 320)

                @inputList.each_with_index do |fld,idx|
                    lstCtrl.insert_item(idx, fld.name)
                    lstCtrl.set_item(idx, 1, fld.df.desc)
                    lstCtrl.set_edit_attr(idx, 2, InplaceEditListCtrl::EDIT_TYPE_EDIT)
#                    lstCtrl.set_edit_attr(idx, 2, InplaceEditListCtrl::EDIT_TYPE_CHOICE, ["aaa","bbb","ccc"])
                end
            end

            def on_ok
                @inputList.each_with_index do |fld,idx|
                    value = @lstCtrl.get_item(idx, 2).get_text
                    fld.setValue(value)
                end # end of @lstCtrl.each
            end
        end # end of class UIGeneral

        class UITeller < UIBase
            define_klass :TELLER

            def initialize(parent, uiDesc)
                super(parent, uiDesc)
                @inputList = uiDesc.action.userInputList
                layoutFields
            end

            def layoutFields
                @uiDesc.flds.each do |fld|
                    fld.createWidget(self)
                end
            end

            def on_ok
            end
        end # end of class UITeller

        class UIPos < UIBase
            define_klass :POS

            def initialize(parent, uiDesc)
                super(parent, uiDesc)

                Wx::StaticText.new(self, -1, "tttttttttt", Wx::Point.new(0,30))
                t = Wx::TextCtrl.new(self, -1, "eeeeeeeee", Wx::Point.new(100,100), Wx::Size.new(200,20))
            end
        end

        class UIAtm < UIBase
            define_klass :ATM
        end # end of class UIAtm

        class UIDesc
            attr_accessor :action, :flds, :klass
            def initialize(action)
                @action = action
                @flds = []
                @klass = UIGeneral
            end

            def wellDefined?
            end

            def doUI
                #        return true unless Wx::App.is_main_loop_running
                dlg = UIDialog.new(nil, self, @klass)
                case dlg.show_modal
                when Wx::ID_OK
                    true
                else
                    false
                end
            end

            class << self
                require 'rexml/document'
                include REXML

                def load(filename, action)
                    input = File.new(filename)
                    doc = Document.new(input)
                    root = doc.root
                    input.close

                    uiDesc = UIDesc.new(action)
                    uiDesc.klass = UIBase.klass_map[root.attribute('type').value.upcase.to_sym] if root.attributes.has_key? 'type'
                    root.elements.each do |elm|
                        uiDesc.flds << loadField(elm)
                    end
                    uiDesc
                end # end of load

                def loadField(node)
                    raise "field type missing for user_interface" unless node.attributes.has_key? 'type'
                    fld = UIField.get_instance(node.attribute('type').value.upcase.to_sym)
                    node.elements.each do |elm|
                        fld.send("#{elm.name}=", elm.text.strip) if fld.respond_to? elm.name
                    end # end of node.elements.each
                    fld
                end # end of loadField
            end # end of class << self
        end # end of class UIDesc
    end # end of module Orgsim
end # end of module Simulator

