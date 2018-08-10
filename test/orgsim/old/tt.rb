require 'wx'

class TheApp < Wx::App
  def on_init
    f = Wx::Frame.new(nil, -1, "absolute", Wx::DEFAULT_POSITION, Wx::Size.new(250,180))
#    f = Wx::Dialog.new(nil, -1, "aaa", Wx::DEFAULT_POSITION, Wx::Size.new(250,180))
    p = Wx::Panel.new(f, -1)
    t = Wx::TextCtrl.new(p, -1, "aaaaaaaaaaaaaaa", Wx::Point.new(-1,-1), Wx::Size.new(250,150))
    f.show
#    f.show_modal
#    false
  end
end

theApp = TheApp.new
theApp.main_loop

