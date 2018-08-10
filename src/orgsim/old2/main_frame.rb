require 'wx'
require 'simulator'
require 'comm'
require 'trans_case'
require 'config'
require 'action_edit_dialog'

module Simulator
  module Orgsim
    class TestStatusBar < Wx::StatusBar
      def initialize(parent)
        super(parent, -1)
        set_fields_count(3)
        self.set_status_text("status bar", 0)
      end
    end # end of class TestStatusBar

    class MainFrame < Wx::Frame
      ID_OPEN = 101
      ID_NEW = 102
      ID_SAVE = 103
      ID_DELETE = 104
      ID_EXIT = 109
      ID_RUN = 201
      ID_EDIT = 202
      ID_CLEAR_LOG = 203
      ID_OPEN_COMM = 301
      ID_CLOSE_COMM = 302
      ID_CONFIG = 303

      attr_accessor :fldDefs

      def initialize(parent, id, title, pos=Wx::DEFAULT_POSITION, size=Wx::DEFAULT_SIZE, style=Wx::DEFAULT_FRAME_STYLE)
        super(parent, id, title, pos, size, style | Wx::CLIP_CHILDREN)
        
        font = Wx::Font.new(8, Wx::FONTFAMILY_SWISS, Wx::FONTSTYLE_NORMAL, Wx::FONTWEIGHT_NORMAL, false, 'Courier New')
        set_font(font)

        @sb = TestStatusBar.new(self)
        set_status_bar(@sb)
        menuBar = Wx::MenuBar.new()
        # File menu
        m1 = Wx::Menu.new()
        m1.append(ID_OPEN, "&Open", "Open Cases Dir")
        evt_menu(ID_OPEN) {|event| on_open_case_dir(event)}
        m1.append(ID_NEW, "&New", "New Test Case")
        evt_menu(ID_NEW) {|event| on_new_case(event)}
        m1.append(ID_SAVE, "&Save", "Save Test Case")
        evt_menu(ID_SAVE) {|event| on_save_case(event)}
        m1.append(ID_DELETE) {|event| on_delete_case(event)}
        m1.append_separator()
        m1.append(ID_EXIT, "&Exit", "Exit")
        menuBar.append(m1, "&File")

        # Tools menu
        m2 = Wx::Menu.new()
        m2.append(ID_OPEN_COMM, "&Open Comm", "Open Communication")
        m2.append(ID_CLOSE_COMM, "&Close Comm", "Close Communication")
        m2.append(ID_CONFIG, "&Config", "Configuration")
        menuBar.append(m2, "&Tools")

        # Abount menu
        m2 = Wx::Menu.new()
        m2.append(201, "&Abount", "abount")
        menuBar.append(m2, "&Abount")

        set_menu_bar(menuBar)

        tb = create_tool_bar(Wx::TB_HORIZONTAL | Wx::NO_BORDER | Wx::TB_FLAT | Wx::TB_TEXT)
        tb.add_tool(ID_NEW, "New", xpm_bitmap('new.xpm'), "New Test Case")
        evt_tool(ID_NEW) {|event| on_new_case(event)}
        tb.add_tool(ID_OPEN, "Open", xpm_bitmap('open.xpm'), "Open Test Case Dir")
        evt_tool(ID_OPEN) {|event| on_open_case_dir(event)}
        tb.add_separator()
        tb.add_tool(ID_EDIT, "Edit", xpm_bitmap('new.xpm'), "Edit Test Case")
        evt_tool(ID_EDIT) {|event| on_edit_case(event)}
        tb.add_tool(ID_SAVE, "Save", xpm_bitmap('new.xpm'), "Save Test Case")
        evt_tool(ID_SAVE) {|event| on_save_case(event)}
        tb.add_tool(ID_DELETE, "Delete", xpm_bitmap('new.xpm'), "Delete Test Case")
        evt_tool(ID_DELETE) {|event| on_delete_case(event)}
        tb.add_separator()
        tb.add_tool(ID_OPEN_COMM, "Open Comm", xpm_bitmap('new.xpm'), "Open Communication")
        evt_tool(ID_OPEN_COMM) {|event| on_open_comm(event)}
        tb.add_tool(ID_CLOSE_COMM, "Close Comm", xpm_bitmap('new.xpm'), "Close Communication")
        evt_tool(ID_CLOSE_COMM) {|event| on_close_comm(event)}
        tb.add_tool(ID_CONFIG, "Config", xpm_bitmap('new.xpm'), "Configuration")
        evt_tool(ID_CONFIG) {|event| on_configuration(event)}
        tb.add_tool(ID_RUN, "Run", xpm_bitmap('new.xpm'), "Run Case")
        evt_tool(ID_RUN) {|event| on_run_case(event)}
        tb.add_tool(ID_CLEAR_LOG, "Clear Log", xpm_bitmap('new.xpm'), "Clear Log")
        evt_tool(ID_CLEAR_LOG) {|event| on_clear_log(event)}
        tb.realize

        @panel = Wx::Panel.new(self,-1)
        sizer = Wx::BoxSizer.new(Wx::VERTICAL)
        sizer.add(@panel, 1, Wx::ALIGN_CENTER|Wx::GROW|Wx::ALL)
        set_auto_layout(true)
        set_sizer(sizer)
        
        @splitter = Wx::SplitterWindow.new(@panel, :style => Wx::NO_BORDER | Wx::SP_3DSASH | Wx::CLIP_CHILDREN)

        @top_splitter = Wx::SplitterWindow.new(@splitter, :style => Wx::NO_BORDER | Wx::SP_3DSASH | Wx::CLIP_CHILDREN)
        panel = Wx::Panel.new(@top_splitter, -1, :style => Wx::CLIP_CHILDREN)
        sizer = Wx::BoxSizer.new(Wx::VERTICAL)
        @tree = Wx::TreeCtrl.new(panel, -1)#, :size => Wx::Size.new(200,200))
        evt_tree_item_activated(-1) {|event| on_tree_item_activated(event)}
        sizer.add(@tree, 1, Wx::ALIGN_TOP | Wx::GROW | Wx::ALL)
        hsizer = Wx::BoxSizer.new(Wx::HORIZONTAL)
        btn = Wx::Button.new(panel, ID_RUN, "Run Case")
        hsizer.add(btn, 0, Wx::ALIGN_CENTER | Wx::GROW | Wx::ALL, 5)
        btn = Wx::Button.new(panel, ID_EDIT, "Edit Action")
        hsizer.add(btn, 0, Wx::ALIGN_CENTER | Wx::GROW | Wx::ALL, 5)
        btn = Wx::Button.new(panel, ID_CLEAR_LOG, "Clear Log")
        hsizer.add(btn, 0, Wx::ALIGN_CENTER | Wx::GROW | Wx::ALL, 5)
        sizer.add(hsizer, 0, Wx::ALIGN_BOTTOM | Wx::GROW | Wx::ALL)
        panel.set_auto_layout(true)
        panel.set_sizer(sizer)
        @log = Wx::TextCtrl.new(@top_splitter, -1, "", :style => Wx::TE_READONLY | Wx::TE_MULTILINE | Wx::TE_DONTWRAP)#, :size => Wx::Size.new(300,200))
        @log.set_font(font)
        TrxnLog.logPanel = @log
        @top_splitter.split_vertically(panel, @log, 300)

        @list = Wx::ListCtrl.new(@splitter, -1, :style => Wx::LC_REPORT | Wx::LC_HRULES | Wx::LC_VRULES)#, :size => Wx::Size.new(500, 100))
        @splitter.split_horizontally(@top_splitter, @list, 300)

        evt_size {|event| on_size(event)}
        evt_close {|event| on_close_window(event)}

        evt_button(ID_RUN) {|event| on_run_case(event)}
        evt_button(ID_EDIT) {|event| on_edit_case(event)}
        evt_button(ID_CLEAR_LOG) {|event| on_clear_log(event)}
      end

      def xpm_bitmap(name)
        filename = File.join(File.dirname(__FILE__), 'icons', name)
        Wx::Bitmap.new(filename, Wx::BITMAP_TYPE_XPM)
      end

      def on_size(event)
        sz = @panel.get_client_size()
        @splitter.set_size(sz)
        event.skip
      end

      def on_close_window(event)
        
        destroy()
      end

      def on_open_case_dir(event)
        dlg = Wx::DirDialog.new(self, "Chose Case Directory:")
        dlg.set_path(File.dirname(File.absolute_path(Config.filename)))
        if dlg.show_modal() == Wx::ID_OK
          dirname = dlg.get_path()
          @root = @tree.add_root(dirname)
          Dir.foreach(dirname) { |name|
            next unless File.extname(name) == ".xml"
            transCase = TransCase.load(@fldDefs, File.join(dirname, name))
            caseItem = @tree.append_item(@root, transCase.desc)
            @tree.set_item_data(caseItem, transCase)
            transCase.actions.each {|action|
              item = @tree.append_item(caseItem, action.klass_name)
              @tree.set_item_data(item, action)
            }
          }
          @tree.expand_all
        end
      end

      def on_new_case(event)
      end

      def on_save_case(event)
      end

      def on_delete_case(event)
      end

      def on_run_case(event)
        item = @tree.get_selection
        caseItem = if @tree.get_item_parent(item) == @tree.get_root_item
                     @tree.get_item_data(item)
                   elsif @tree.get_item_parent(@tree.get_item_parent(item)) == @tree.get_root_item
                     @tree.get_item_data(@tree.get_item_parent(item))
                   else
                     nil
                   end
        return unless caseItem
        @fldDefs.clear
        caseItem.runCase
      end

      def on_edit_case(event)
        item = @tree.get_selection
        if @tree.get_item_parent(@tree.get_item_parent(item)) == @tree.get_root_item
          action = @tree.get_item_data(item)
          dlg = ActionEditDialog.new(action)
          dlg.show_modal()
        end
      end

      def on_clear_log(event)
      end

      def on_open_comm(event)
        @comm = Communication.getCommunication
      end

      def on_close_comm(event)
        return unless @comm
        @comm.quit
        @comm = nil
      end

      def on_configuration(event)
      end

      def on_tree_item_activated(event)
        item = event.get_item()
        if @tree.get_item_parent(@tree.get_item_parent(item)) == @tree.get_root_item
          on_edit_case(event)
        end
      end

    end
  end # end of module Orgsim
end # end of module Simulator

