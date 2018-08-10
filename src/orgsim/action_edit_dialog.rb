require 'wx'
require 'simulator'
require 'trans_case'
require 'inplace_edit_listctrl'

module Simulator
    module Orgsim
        class ActionListCtrl < InplaceEditListCtrl
            def initialize(action, fullnameList, parent, edit_attrs=[])
                super(parent, edit_attrs)

                @action = action
                @fullnameList = fullnameList
                @value_types = ValueType.klass_map.keys.sort.collect {|s| s.to_s} 

                insert_column(0, "Field Name")
                insert_column(1, "Description")
                set_column_width(1, 160)
                insert_column(2, "Value Type")
                insert_column(3, "Value")
                set_column_width(3, 320)

                genLayout
            end

            def set_item(row, col, label, imageId=-1)
                super
                @action.changed = true
            end

            def genLayout
                @action.flds.each_with_index do |f,idx|
                    layoutField(f, idx)
                end
            end # end of def layoutFields

            def layoutField(fld, idx)
                insert_item(idx, fld.name)
                set_item(idx, 1, fld.df.desc)
                set_item(idx, 2, fld.generator.klass_name)
                set_edit_attr(idx, 2, InplaceEditListCtrl::EDIT_TYPE_CHOICE, @value_types)
                case fld.generator
                when ValueTypeFixed
                    set_item(idx, 3, fld.generator.value)
                    set_edit_attr(idx, 3, InplaceEditListCtrl::EDIT_TYPE_EDIT)
                when ValueTypeFromConfig
                when ValueTypeVariableCard
                    set_item(idx, 3, fld.generator.column)
                    set_edit_attr(idx, 3, InplaceEditListCtrl::EDIT_TYPE_CHOICE, Card.columns)
                when ValueTypeVariableAcquirer
                    set_item(idx, 3, fld.generator.column)
                    set_edit_attr(idx, 3, InplaceEditListCtrl::EDIT_TYPE_CHOICE, Acquirer.columns)
                when ValueTypePreviousOutgoing
                    set_item(idx, 3, fld.generator.field_name)
                    set_edit_attr(idx, 3, InplaceEditListCtrl::EDIT_TYPE_CHOICE, @fullnameList)
                when ValueTypePreviousIncoming
                    set_item(idx, 3, fld.generator.field_name)
                    set_edit_attr(idx, 3, InplaceEditListCtrl::EDIT_TYPE_CHOICE, @fullnameList)
                end # end of case
            end # end of layoutField

            def insert(idx, fld)
                layoutField(fld, idx)
            end
        end

        class AllFieldsListCtrl < Wx::ListCtrl
            def initialize(action, fullnameList, parent)
                @action = action
                @fullnameList = fullnameList
                @visibles = fullnameList.select {|v| !action.hasField? v[0]}
                super(parent, :size => Wx::Size.new(200,300), :style => Wx::LC_REPORT | Wx::LC_HRULES | Wx::LC_VRULES)
                insert_column(0, "Field Name")
                insert_column(1, "Description")
                set_column_width(1, 160)
                layoutFields
            end

            def layoutFields
                @visibles.each_with_index do |v,idx|
                    insert_item(idx, v[0])
                    set_item(idx, 1, v[1])
                end
            end

            def insert(name)
                idx = @visi
            end

            def hasField?(name)
                @visibles.find {|v| v[0] == name}
            end

            def findIndex(name)
                @visibles.find_index {|v| v[0] == name}
            end
        end

        class ActionEditDialog < Wx::Dialog
            ID_EXPAND = 10
            ID_ADD_FIELD = 20
            ID_DEL_FIELD = 30

            def initialize(action, parent=nil)
                @action = action
                @fullnameList = action.fldDefs.fullnameList
                super(parent, -1, 'Action Edit', Wx::DEFAULT_POSITION, Wx::Size.new(800,400))

                center_on_screen(Wx::BOTH)
                sizer = Wx::BoxSizer.new(Wx::VERTICAL)

                hsizer = Wx::BoxSizer.new(Wx::HORIZONTAL)
                s = Wx::StaticText.new(self, -1, "direction:")
                hsizer.add(s, 0, Wx::ALIGN_CENTER | Wx::ALL, 5)
                s = Wx::StaticText.new(self, -1, action.klass_name)
                hsizer.add(s, 0, Wx::ALIGN_CENTER | Wx::ALL, 5)
                @textExpand = Wx::StaticText.new(self, -1, "expand")
                hsizer.add(@textExpand, 0, Wx::ALIGN_CENTER | Wx::ALL, 5)
                @btnExpand = Wx::Button.new(self, ID_EXPAND, ">>>")
                hsizer.add(@btnExpand, 0, Wx::ALIGN_CENTER | Wx::ALL, 5)
                sizer.add(hsizer, 0, Wx::ALIGN_CENTER | Wx::ALL, 5)
                @expanded = false

                @hsizer = Wx::BoxSizer.new(Wx::HORIZONTAL)
                @actionListCtl = ActionListCtrl.new(action, @fullnameList, self)
                @hsizer.add(@actionListCtl, 1, Wx::ALIGN_CENTER|Wx::GROW|Wx::ALL, 5)
                vsizer = Wx::BoxSizer.new(Wx::VERTICAL)
                @btnAdd = Wx::Button.new(self, ID_ADD_FIELD, "<<")
                @btnAdd.hide
                vsizer.add(@btnAdd, 0, Wx::ALIGN_CENTER|Wx::GROW|Wx::ALL, 5)
                @btnDel = Wx::Button.new(self, ID_DEL_FIELD, ">>")
                @btnDel.hide
                vsizer.add(@btnDel, 0, Wx::ALIGN_CENTER|Wx::GROW|Wx::ALL, 5)
                @hsizer.add(vsizer, 0, Wx::ALIGN_CENTER|Wx::GROW|Wx::ALL, 5)
                @lstAllFlds = AllFieldsListCtrl.new(action, @fullnameList, self)
                @lstAllFlds.hide
                @hsizer.add(@lstAllFlds, 0, Wx::ALIGN_CENTER|Wx::GROW|Wx::ALL, 5)
                sizer.add(@hsizer, 1, Wx::ALIGN_CENTER | Wx::GROW | Wx::ALL | Wx::EXPAND, 5)

                t = Wx::TextCtrl.new(self, -1, "bla bla bla", Wx::DEFAULT_POSITION, Wx::DEFAULT_SIZE)
                sizer.add(t, 0, Wx::ALIGN_CENTER|Wx::GROW|Wx::ALL, 5)

                button_sizer = Wx::StdDialogButtonSizer.new
                button_sizer.add(Wx::Button.new(self, Wx::ID_OK, "OK"))
                button_sizer.add(Wx::Button.new(self, Wx::ID_CANCEL, "CANCEL"))
                button_sizer.realize
                sizer.add(button_sizer, 0, Wx::ALIGN_CENTER | Wx::GROW | Wx::ALL, 5)

                evt_button(ID_EXPAND) {|event| on_expand_click(event)}
                evt_button(ID_ADD_FIELD) {|event| on_add_field(event)}
                evt_button(ID_DEL_FIELD) {|event| on_del_field(event)}

                set_auto_layout(true)
                set_sizer(sizer)
                on_expand_click(nil)
            end

            def on_expand_click(event)
                if @expanded
                    @textExpand.set_label("expand")
                    @btnExpand.set_label(">>>")
                    @btnAdd.hide
                    @btnDel.hide
                    @lstAllFlds.hide
                    @expanded = false
                else
                    @textExpand.set_label("shrink")
                    @btnExpand.set_label("<<<")
                    @btnAdd.show
                    @btnDel.show
                    @lstAllFlds.show
                    @expanded = true
                end
                @hsizer.layout
            end

            def on_add_field(event)
                selects = []
                @lstAllFlds.get_selections.each do |idx|
                    selects << idx
                    name = @lstAllFlds.get_item(idx, 0).get_text
                    df = @action.fldDefs.findField(name)
                    fld = CaseField.new(name, df, @action)
                    fld.generator = ValueType.get_instance(:USER_INPUT, fld.df.codec)
                    # find next field
                    nextIndex = nil
                    @fullnameList[(@fullnameList.find_index {|v| v[0] == name} + 1) .. -1].each do |v|
                        break if nextIndex = @action.findIndex(v[0])
                    end
                    @action.insert(nextIndex, fld)
                    @actionListCtl.insert(nextIndex, fld)
                end # end of get_selections.each do
                selects.reverse.each {|idx| @lstAllFlds.delete_item(idx)}
            end # end of on_add_field

            def on_del_field(event)
                selects = []
                @actionListCtl.get_selections.each do |idx|
                    selects << idx
                    name = @actionListCtl.get_item(idx, 0).get_text
                    idx = @action.findIndex(name)
                    fld = @action.delete(idx)
                    # find next field
                    nextIndex = nil
                    @fullnameList[(@fullnameList.find_index {|v| v[0] == name} + 1) .. -1].each do |v|
                        break if nextIndex = @lstAllFlds.findIndex(v[0])
                    end
                    nextIndex = nextIndex - 1     # don't know why should -1
                    @lstAllFlds.insert_item(nextIndex, name)
                    @lstAllFlds.set_item(nextIndex, 1, fld.df.desc)
                end # end of get_selections.each do
                selects.reverse.each {|idx| @actionListCtl.delete_item(idx)}
            end # end of on_del_field
        end # end of ActionEditDialog
    end # end of module Orgsim
end # end of module Simulator

