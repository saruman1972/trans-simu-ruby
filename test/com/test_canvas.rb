require 'simulator'
require 'wx'
require 'canvas'

class TestFrame < Wx::Frame
  def initialize(parent)
    super(parent, -1, 'test_canvas')
    sizer = Wx::BoxSizer.new(Wx::VERTICAL)

    canvas = Canvas.new(self)
    draw_canvas(canvas)
    sizer.add(canvas, 1, Wx::GROW)
    @canvas = canvas

    set_sizer(sizer)
    set_auto_layout(true)

    @cursor_sizenesw = Wx::Cursor.new(Wx::CURSOR_SIZENESW)
    @cursor_sizens = Wx::Cursor.new(Wx::CURSOR_SIZENS)
    @cursor_sizenwse = Wx::Cursor.new(Wx::CURSOR_SIZENWSE)
    @cursor_sizewe = Wx::Cursor.new(Wx::CURSOR_SIZEWE)
    @cursor_ibeam = Wx::Cursor.new(Wx::CURSOR_IBEAM)

    @cursor = Wx::Cursor.new(Wx::CURSOR_IBEAM)

    evt_canvas_left_down() {|event| on_canvas_left_down(event)}
  end

  def draw_canvas(canvas)
    @rect = canvas.create_rectangle(10,10,100,100, 'RED', 'SOLID', 1, 'RED')
    canvas.bind(@rect, Canvas::EVT_CANVAS_LEFT_DOWN) {|object, event| on_object_left_down(object, event)}
#    @rect.bind(Canvas::EVT_CANVAS_ENTER_OBJECT) {|object, event| on_object_enter(object, event)}
#    @rect.bind(Canvas::EVT_CANVAS_LEAVE_OBJECT) {|object, event| on_object_leave(object, event)}

    @circle = canvas.create_circle(200,10,100, 'BLUE', 'SOLID', 1, 'BLUE')
    @ellipse = canvas.create_ellipse(10,200,150,100, 'BLUE', 'SOLID', 1, 'BLUE')
#    @line = canvas.create_line([[200,200],[300,300]])
    @text = canvas.create_text('this is a text', 50, 50)

    canvas.bind('obj', Canvas::EVT_CANVAS_ENTER_OBJECT) {|object, event| on_object_enter(object, event)}
    canvas.bind('obj', Canvas::EVT_CANVAS_LEAVE_OBJECT) {|object, event| on_object_leave(object, event)}
    canvas.bind(@text, Canvas::EVT_CANVAS_LEFT_DOWN) {|object, event| on_object_left_down(object, event)}

    canvas.add_tag_withtag('obj', @rect)
    canvas.add_tag_withtag('obj', @circle)
#    canvas.add_tag_withtag('obj', @ellipse)
  end

  def on_canvas_left_down(event)
#    rgn = Wx::Region.create_circle_rgn(200,10,100)
#    if rgn.contains(event.coords.x, event.coords.y)
#      p "inside circle"
#    end
#    rgn = Wx::Region.create_ellipse_rgn(10,200,150,100)
#    if rgn.contains(event.coords.x, event.coords.y)
#      p "inside ellipse"
#      return
#    end
#    rgn = Wx::Region.create_line_rgn(Wx::Point.new(200,200),Wx::Point.new(300,300),1)
#    if rgn.contains(event.coords.x, event.coords.y)
#      p "inside line"
#      return
#    end
#    p "aaaaaaaaaaaaaaaa"
#    @canvas.move(@rect, event.coords.x - @rect.x, event.coords.y - @rect.y)

    @org_x = event.coords.x
    @org_y = event.coords.y

    if tags = @canvas.find_tags_overlapping(event.coords.x, event.coords.y, event.coords.x+1, event.coords.y+1)
      evt_canvas_left_up() {|event| on_move_obj_up(event)}
      evt_canvas_motion() {|event| on_move_obj_motion(event)}
      @canvas.capture_mouse
      @move_tags = tags
      return
    end

    @track_rect = @canvas.create_rectangle(event.coords.x, event.coords.y, 0, 0, 'BLACK', 'DOT', 1, 'WHITE', 'TRANSPARENT')
    evt_canvas_left_up() {|event| on_canvas_left_up(event)}
    @canvas.capture_mouse
    evt_canvas_motion() {|event| on_canvas_motion(event)}
  end

  def on_move_obj_up(event)
    @canvas.release_mouse
    evt_canvas_motion() {|event| }
    evt_canvas_left_up() {|event| }
  end

  def on_move_obj_motion(event)
    @move_tags.each {|tag|
      @canvas.move(tag, event.coords.x-@org_x, event.coords.y-@org_y)
    }
    @canvas.draw
    @org_x = event.coords.x
    @org_y = event.coords.y
  end

  def on_canvas_left_up(event)
    @canvas.release_mouse
    evt_canvas_motion() {|event| }
    evt_canvas_left_up() {|event| }

    @canvas.remove_object(@track_rect)
    @track_rect = nil
    @canvas.draw
  end

  def on_canvas_motion(event)
    @canvas.coords(@track_rect, @org_x, @org_y, event.coords.x - @org_x, event.coords.y - @org_y)
    @canvas.draw
  end

  def on_object_left_down(object, event)
    p object
    p "object left down"
  end

  def on_object_enter(object, event)
    set_cursor(@cursor)
  end

  def on_object_leave(object, event)
    set_cursor(Wx::STANDARD_CURSOR)
  end
end

class TheApp < Wx::App
  def on_init
    f = TestFrame.new(nil)
    f.show
  end
end

app = TheApp.new
app.main_loop
