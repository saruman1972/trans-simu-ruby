require 'wx'

  EVT_CANVAS_LEFT_DOWN    = Wx::Event.new_event_type()

  class MyEvent < Wx::CommandEvent
    def initialize(event_type, native_event, id, coords=nil)
      super(event_type, id)
      set_event_type(event_type)
      @native_event = native_event
      @coords = coords
    end
  end

  Wx::EvtHandler.register_class(MyEvent, EVT_CANVAS_LEFT_DOWN, 'evt_canvas_left_down', 0)

class MyFrame < Wx::Frame
  def initialize(parent)
    super(parent)
    
    evt_canvas_left_down {|event| on_my_left_down(event)}
    evt_left_down {|event| on_left_down(event)}
  end

  def on_left_down(event)
    pt = event.get_position
    evt = MyEvent.new(EVT_CANVAS_LEFT_DOWN, event, get_id(), pt)
    get_event_handler.process_event(evt)
  end

  def on_my_left_down(event)
    p "my left down"
  end
end

class TheApp < Wx::App
  def on_init
    f = MyFrame.new(nil)
    f.show
  end
end


app = TheApp.new
app.main_loop
