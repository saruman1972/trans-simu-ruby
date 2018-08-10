require 'wx'
require 'simulator'
require 'ui_design'

class TheApp < Wx::App
  def on_init
    dlg = Simulator::Orgsim::UiDesign.new(nil)
    dlg.show_modal
    false
  end
end

app = TheApp.new
app.main_loop
