require 'wx'

class InplaceEditListCtrl < Wx::ListCtrl
  class InplaceEdit < Wx::TextCtrl
    def initialize(row, col, parent, id, val='', pos=Wx::DEFAULT_POSITION, size=Wx::DEFAULT_SIZE, style=0)
      @row = row
      @col = col
      super(parent, id, val, pos, size, style | Wx::TE_PROCESS_ENTER | Wx::TE_NOHIDESEL)
      evt_text_enter(id) {|event| on_text_enter(event)}
      evt_key_down() {|event| on_char(event)}
      evt_kill_focus() {|event| on_kill_focus(event)}

      set_font(get_parent.get_font)
      set_selection(-1,-1)
      set_focus
    end

    def on_kill_focus(event)
      # send notify message
      msg = if @is_escaped
              nil
            else
              get_parent.set_item(@row, @col, get_value)
            end
      # send message
      destroy
    end

    def on_text_enter(event)
      get_parent.set_focus
    end

    def on_char(event)
      if event.get_key_code == Wx::K_ESCAPE
        @is_escaped = true
        get_parent.set_focus
      else
        event.skip
      end
    end
  end # end of class InplaceEdit

  class InplaceChoice < Wx::Choice
    def initialize(row, col, parent, id, pos, size, choices, cur_value=nil, style=0)
      @row = row
      @col = col
      @choices = choices
      dispChoices = if choices[0].kind_of? Array
                      choices.collect {|ar| ar.join(' - ')}
                    else
                      choices
                    end
      cur_sel = if choices[0].kind_of? Array
                  choices.find_index {|ar| ar[0] == cur_value}
                else
                  choices.find_index {|c| c == cur_value}
                end
      super(parent, id, pos, size, dispChoices, style)

      evt_kill_focus() {|event| on_kill_focus(event)}
      evt_char() {|event| on_char(event)}
      evt_key_down() {|event| on_char(event)}
      evt_choice(id) {|event| on_choice(event)}

      set_selection(cur_sel) if cur_sel
      @prev_selection = cur_sel
      set_font(get_parent.get_font)
      set_focus
    end

    def on_choice(event)
      if get_selection != @prev_selection
        @changed = true
        @prev_selection = get_selection
      end
    end

    def on_kill_focus(event)
      # send notify message
      msg = if @changed && !@is_escaped && get_selection >= 0
              if @choices[0].kind_of? Array
                get_parent.set_item(@row, @col, @choices[get_selection][0])
              else
                get_parent.set_item(@row, @col, get_label)
              end
            end
      # send message
      destroy
    end

    def on_char(event)
      # RETURN or ESC
      if event.get_key_code == Wx::K_RETURN or event.get_key_code == Wx::K_ESCAPE
        @is_escaped = true
        get_parent.set_focus
      else
        event.skip
      end
    end
  end # end of InplaceChoice

  EDIT_TYPE_NONE = 0
  EDIT_TYPE_EDIT = 1
  EDIT_TYPE_CHOICE = 2

  class ItemAttr
    attr_accessor :type, :choices

    def initialize(type, choices=nil)
      @type = type
      @choices = choices
    end
  end
  
  def initialize(parent, edit_attrs=[])
    @edit_attrs = edit_attrs
    super(parent, :pos => Wx::DEFAULT_POSITION, :size => Wx::DEFAULT_SIZE, :style => Wx::LC_REPORT | Wx::LC_HRULES | Wx::LC_VRULES)
    evt_list_item_activated(get_id()) {|event| on_item_activated(event)}
    evt_left_down() {|event| on_left_down(event)}
    evt_left_dclick() {|event| on_left_dclick(event)}
    evt_scrollwin() {|event| on_scroll(event)}
    evt_list_begin_label_edit(get_id()) {|event| on_begin_label_edit(event)}

    evt_right_down() {|event| on_right_down(event)}
  end

  def set_edit_attr(row, col, type, choices=nil)
    @edit_attrs[row] ||= []
    @edit_attrs[row][col] = ItemAttr.new(type, choices)
  end

  def get_edit_attr(row, col)
    return nil unless @edit_attrs[rows]
    @edit_attrs[rows][col]
  end

  def on_begin_label_edit(event)
    print "event=#{event}\n"
  end

  def on_item_activated(event)
    item = event.get_item
    print "id=#{item.get_id},column=#{item.get_column},index=#{event.get_index},text=#{item.get_text}\n"
  end

  def on_scroll(event)
    # if event.get_orientation == Wx::HORIZONTAL or Wx::VERTICAL
    set_focus
    event.skip
  end

  def on_right_down(event)
        evt = Wx::ListEvent.new(Wx::EVT_COMMAND_LIST_ITEM_ACTIVATED, get_id())
        item = Wx::ListItem.new
        item.set_id(1)
        item.set_column(2)
        item.set_text('bbbbbbbbbbb')
#        evt.set_item(item)
    evt.set_int(1)
    evt.set_string('aaaaaaaaaaaaa')
    evt.set_client_data(item)
        get_event_handler.process_event(evt)
  end

  def on_left_down(event)
    set_focus
    inplace_edit_handle(event)
  end

  def on_left_dclick(event)
    inplace_edit_handle(event)
event.skip
  end

  def inplace_edit_handle(event)
    row,col = hit_test_ex(event.get_position)
    unless (row == Wx::NOT_FOUND)
      if get_item_state(row, Wx::LIST_STATE_FOCUSED) & Wx::LIST_STATE_FOCUSED == Wx::LIST_STATE_FOCUSED
        show_inplace_edit(row,col)
      else
#        set_item_state(row, Wx::LIST_STATE_FOCUSED | Wx::LIST_STATE_SELECTED, Wx::LIST_STATE_FOCUSED | Wx::LIST_STATE_SELECTED)
        event.skip
      end
    else
      event.skip
    end
  end

  def hit_test_ex(pos)
    row = get_top_item
    bottom = row + get_count_per_page
    bottom = get_item_count if bottom > get_item_count
    row.upto(bottom) {|index|
      rect = get_item_rect(index)
      if rect.contains(pos)
        get_column_count.times {|col|
          return index,col if pos.x >= rect.x && pos.x <= (rect.x+get_column_width(col))
          rect.set_x(rect.x + get_column_width(col))
        }
      end
    }
    return Wx::NOT_FOUND,Wx::NOT_FOUND
  end

  def calc_inplace_edit_rect(row,col)
    rect = get_item_rect(row)
    offset = 0
    col.times {|i| offset += get_column_width(i)}
    rectClient = get_client_rect
    if (offset + rect.x < 0) || (offset + rect.x > rectClient.right)
      # there is a bug here, has'nt fix yet
      scroll_window(-(offset+rect.x), 0)
    end
    #            rect.set_x(offset+4)
    rect.set_x(rect.x + offset)
    rect.set_width(get_column_width(col) - 3)
    height = rect.bottom - rect.top
#         rect.set_height(5 * rect.height)
    rect.set_width(get_column_width(col))
#         rect.right = rectClient.right if (rect.right > rectClient.right)
    rect
  end

  def show_inplace_edit(row,col)
    return unless @edit_attrs[row]
    attr = @edit_attrs[row][col]
    return unless attr
    case attr.type
      when EDIT_TYPE_EDIT
        rect = calc_inplace_edit_rect(row,col)
        rect.set_height(rect.height + 6)
        rect.set_y(rect.y - 3)
        InplaceEdit.new(row, col, self, -1, get_item(row,col).get_text, rect.top_left, rect.get_size)
      when EDIT_TYPE_CHOICE
        rect = calc_inplace_edit_rect(row,col)

        evt = Wx::ListEvent.new(Wx::EVT_COMMAND_LIST_ITEM_ACTIVATED)
        item = Wx::ListItem.new
        item.set_id(1)
        item.set_column(2)
#         evt.set_item(item)
        add_pending_event(evt)
        get_event_handler.process_event(evt)

        rect.set_height(rect.height - 3)
        rect.set_y(rect.y - 3)
        InplaceChoice.new(row, col, self, -1, rect.top_left, rect.get_size, attr.choices, get_item(row,col).get_text)
    end
  end
end # end of class InplaceEditListCtrl

