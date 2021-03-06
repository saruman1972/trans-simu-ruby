require 'wx'

class Wx::Region
  def self.create_round_rect_rgn(x, y, width, height, ellipse_width, ellipse_height)
    # check if we can do a normal rectangle instead
    return self.new(x, y, width, height) if ellipse_width == 0 || ellipse_height == 0

    # make the dimension sensible
    ellipse_width = -ellipse_width if ellipse_width < 0
    ellipse_height = -ellipse_height if ellipse_height < 0

    # create region (zero region)
    rgn = self.new(0,0,0,0)
    
    # check parameters
    ellipse_width = width if ellipse_width > width
    ellipse_height = height if ellipse_height > height

    # Ellipse algorithm, based on an article by K. Porter
    # in DDJ Graphics Programming Column, 8/89
    asq = ellipse_width * ellipse_width / 4            # a^2
    bsq = ellipse_height * ellipse_height / 4          # b^2
    asq = 1 if (asq == 0)
    bsq = 1 if (bsq == 0)
    d = bsq - asq * ellipse_height / 2 + asq / 4       # b^2 - a^2b + a^2/4
    xd = 0
    yd = asq * ellipse_height                          # 2a^2b
    rx = x + ellipse_width / 2
    rwidth = width - ellipse_width

    # loop to draw first half of quadrant
    while xd < yd
      if d > 0    # if nearest pixel is toward the center
        # move toward center
        rgn.union(rx, y, rwidth, 1)
        rgn.union(rx, y+height, rwidth, 1)
        y = y + 1
        height = height - 2
        yd = yd - 2*asq
        d = d - yd
      end # end of if d > 0
      rx = rx - 1        # next horiz point
      rwidth = rwidth + 2
      xd = xd + 2*bsq
      d = d + bsq + xd
    end # end of while xd < yd

    # loop to draw second half of quadrant
    d = d + (3 * (asq-bsq) / 2 - (xd+yd)) /2
    while yd >= 0
      # next vertical point
      rgn.union(rx, y, rwidth, 1)
      rgn.union(rx, y+height, rwidth, 1)
      y = y + 1
      height = height - 2
      if d < 0    # if nearest pixel is outside ellipse
        rx = rx - 1    # move away from center
        rwidth = rwidth + 2
        xd = xd + 2*bsq
        d = d + xd
      end # end of if d < 0
      yd = yd - 2*asq
      d = d + asq - yd
    end # end of while yd >= 0

    # Add the inside rectangle
    rgn.union(x, y, width, height) if (height >= 0)

    rgn
  end # end of create_round_rect_rgn

  def self.create_ellipse_rgn(x, y, width, height)
    create_round_rect_rgn(x, y, width, height, width, height)
  end

  def self.create_circle_rgn(x, y, width)
    create_round_rect_rgn(x, y, width, width, width, width)
  end

  def self.create_line_rgn(p1, p2, width)
    if p1.x > p2.x
      p1,p2 = p2,p1
    end
    half_width = (width+5)/2
    pts = 
      if p1.y <= p2.y
        [Wx::Point.new(p1.x - half_width, p1.y + half_width),
         Wx::Point.new(p1.x + half_width, p1.y - half_width),
         Wx::Point.new(p2.x + half_width, p2.y - half_width),
         Wx::Point.new(p2.x - half_width, p2.y + half_width)]
      else
        [Wx::Point.new(p1.x - half_width, p1.y - half_width),
         Wx::Point.new(p1.x + half_width, p1.y + half_width),
         Wx::Point.new(p2.x + half_width, p2.y + half_width),
         Wx::Point.new(p2.x - half_width, p2.y - half_width)]
      end
    Wx::Region.new(4, pts)          # this does'nt work because of wxruby bug
  end
end # end of class Wx::Region

class Canvas < Wx::Panel
  EVT_CANVAS_LEFT_DOWN     = Wx::Event.new_event_type()
  EVT_CANVAS_LEFT_UP       = Wx::Event.new_event_type()
  EVT_CANVAS_LEFT_DCLICK   = Wx::Event.new_event_type()
  EVT_CANVAS_RIGHT_DOWN    = Wx::Event.new_event_type()
  EVT_CANVAS_RIGHT_UP      = Wx::Event.new_event_type()
  EVT_CANVAS_RIGHT_DCLICK  = Wx::Event.new_event_type()
  EVT_CANVAS_MOTION        = Wx::Event.new_event_type()

  EVT_CANVAS_ENTER_OBJECT  = Wx::Event.new_event_type()
  EVT_CANVAS_LEAVE_OBJECT  = Wx::Event.new_event_type()

  class CanvasMouseEvent < Wx::CommandEvent
    attr_reader :coords

    def initialize(event_type, native_event, id, coords=nil)
      super(event_type, id)
      set_event_type(event_type)
      @native_event = native_event
      @coords = coords
    end
  end

  Wx::EvtHandler.register_class(CanvasMouseEvent, EVT_CANVAS_LEFT_DOWN, 'evt_canvas_left_down', 0)
  Wx::EvtHandler.register_class(CanvasMouseEvent, EVT_CANVAS_LEFT_UP, 'evt_canvas_left_up', 0)
  Wx::EvtHandler.register_class(CanvasMouseEvent, EVT_CANVAS_LEFT_DCLICK, 'evt_canvas_left_dclick', 0)
  Wx::EvtHandler.register_class(CanvasMouseEvent, EVT_CANVAS_RIGHT_DOWN, 'evt_canvas_right_down', 0)
  Wx::EvtHandler.register_class(CanvasMouseEvent, EVT_CANVAS_RIGHT_UP, 'evt_canvas_right_up', 0)
  Wx::EvtHandler.register_class(CanvasMouseEvent, EVT_CANVAS_RIGHT_DCLICK, 'evt_canvas_right_dclick', 0)
  Wx::EvtHandler.register_class(CanvasMouseEvent, EVT_CANVAS_MOTION, 'evt_canvas_motion', 0)

  Wx::EvtHandler.register_class(CanvasMouseEvent, EVT_CANVAS_ENTER_OBJECT, 'evt_canvas_enter_object', 0)
  Wx::EvtHandler.register_class(CanvasMouseEvent, EVT_CANVAS_LEAVE_OBJECT, 'evt_canvas_leave_object', 0)

  class DrawObject
    attr_accessor :canvas, :hit_color, :brush, :pen, :hit_line, :hit_fill, :hit_line_width, :min_hit_line_width, :hit_fill_style, :hit_coords
    attr_accessor :tags, :rgn

    Struct.new("BrushParm", :color, :style)
    Struct.new("PenParm", :color, :style, :line_width)

    @@brush_list = {
      Struct::BrushParm.new('NONE', 'TRANSPARENT')  => Wx::NULL_BRUSH
      # Struct::BrushParm.new(, :SOLID)        => Wx::BLUE_BRUSH,
      # Struct::BrushParm.new(:GREEN, :SOLID)       => Wx::GREEN_BRUSH,
      # Struct::BrushParm.new(:WHITE, :SOLID)       => Wx::WHITE_BRUSH,
      # Struct::BrushParm.new(:BLACK, :SOLID)       => Wx::BLACK_BRUSH,
      # Struct::BrushParm.new(:GREY, :SOLID)        => Wx::GREY_BRUSH,
      # Struct::BrushParm.new(:MEDIUM_GREY, :SOLID) => Wx::MEDIUM_GREY_BRUSH,
      # Struct::BrushParm.new(:LIGHT_GREY, :SOLID)  => Wx::LIGHT_GREY_BRUSH,
      # Struct::BrushParm.new(:CYAN, :SOLID)        => Wx::CYAN_BRUSH,
      # Struct::BrushParm.new(:RED, :SOLID)         => Wx::RED_BRUSH
    }

    @@pen_list = {
      Struct::PenParm.new('NONE', 'TRANSPARENT', 1)  => Wx::NULL_PEN
  #     Struct::PenParm.new(:BLUE, :SOLID, 1)        => Wx::BLUE_PEN,
  #     Struct::PenParm.new(:GREEN, :SOLID, 1)       => Wx::GREEN_PEN,
  #     Struct::PenParm.new(:WHITE, :SOLID, 1)       => Wx::WHITE_PEN,
  #     Struct::PenParm.new(:BLACK, :SOLID, 1)       => Wx::BLACK_PEN,
  #     Struct::PenParm.new(:GREY, :SOLID, 1)        => Wx::GREY_PEN,
  #     Struct::PenParm.new(:MEDIUM_GREY, :SOLID, 1) => Wx::MEDIUM_GREY_PEN,
  #     Struct::PenParm.new(:LIGHT_GREY, :SOLID, 1)  => Wx::LIGHT_GREY_PEN,
  #     Struct::PenParm.new(:CYAN, :SOLID, 1)        => Wx::CYAN_PEN,
  #     Struct::PenParm.new(:RED, :SOLID, 1)         => Wx::RED_PEN
    }

    @@fill_style_list = {
       'TRANSPARENT'      => Wx::TRANSPARENT,
       'SOLID'            => Wx::SOLID,
       'BDIAGNOAL_HATCH'  => Wx::BDIAGONAL_HATCH,
       'CROSS_HATCH'      => Wx::CROSSDIAG_HATCH,
       'FDIAGONAL_HATCH'  => Wx::FDIAGONAL_HATCH,
       'CROSS_HATCH'      => Wx::CROSS_HATCH,
       'HORIZONTAL_HATCH' => Wx::HORIZONTAL_HATCH,
       'VERTICAL_HATCH'   => Wx::VERTICAL_HATCH
    }

    @@line_style_list = {
       'SOLID'       => Wx::SOLID,
       'TRANSPARENT' => Wx::TRANSPARENT,
       'DOT'         => Wx::DOT,
       'LONG_DASH'   => Wx::LONG_DASH,
       'SHORT_DASH'  => Wx::SHORT_DASH,
       'DOT_DASH'    => Wx::DOT_DASH
    }

    def initialize(canvas)
      @hit_line = true
      @hit_fill = true
      @hit_line_width = 3
      @min_hit_line_width = 3
      @hit_fill_style = 'SOLID'

      @canvas = canvas
      @hit_color = Canvas.next_color
      set_hit_pen(@hit_color, @hit_line_width)
      set_hit_brush(@hit_color)
      canvas << self

      @tags = []
    end

    def set_brush(fill_color, fill_style)
      if fill_color == nil or fill_style == nil
        @brush = Wx::NULL_BRUSH
        @fill_style = :TRANSPARENT
      else
        @brush = Wx::Brush.new(fill_color, @@fill_style_list[fill_style])
        @@brush_list[Struct::BrushParm.new(fill_color, fill_style)] = @brush
      end
    end

    def set_pen(line_color, line_style, line_width)
      if line_color == nil or line_style == nil
        @brush = Wx::NULL_PEN
        @fill_style = :TRANSPARENT
      else
        @pen = Wx::Pen.new(line_color, line_width, @@line_style_list[line_style])
        @@pen_list[Struct::PenParm.new(line_color, line_style, line_width)] = @pen
      end
    end

    def set_hit_brush(hit_color)
      if @hit_fill
        @hit_brush = Wx::Brush.new(hit_color, @@fill_style_list['SOLID'])
        @@brush_list[Struct::BrushParm.new(hit_color, 'SOLID')] = @hit_brush
      else
        @hit_brush = Wx::NULL_BRUSH
      end
    end

    def set_hit_pen(hit_color, line_width)
      if @hit_line
        @hit_pen = Wx::Pen.new(hit_color, line_width, @@line_style_list['SOLID'])
        @@pen_list[Struct::PenParm.new(hit_color, 'SOLID', line_width)] = @hit_pen
      else
      end
    end

    def calc_bounding_box()
      xs = @points.collect {|p| p.x}
      ys = @points.collect {|p| p.y}
      @bounding_box = Wx::Rect.new(xs.min, ys.min, xs.max, ys.max)
      @canvas.bounding_box_dirty = true
    end

    def set_points(points)
      @points = points.clone
      calc_bounding_box
    end

    def add_tag(tag)
      return if @tags.index(tag)
      @tags << tag
    end

    def remove_tag(tag)
      @tags.delete(tag)
    end
  end

  class DrawObjectLine < DrawObject
    def initialize(canvas, points, line_color='BLACK', line_style='SOLID', line_width=1)
      super(canvas)
      set_points(points)
      @line_color = line_color
      @line_style = line_style
      @line_width = line_width

      set_pen(line_color, line_style, line_width)
      @hit_line_width = line_width > @min_hit_line_width ? line_width : @min_hit_line_width

#      @rgn = Wx::Region.create_line_rgn(points.cnt, points)
    end

    def draw(dc, hit_dc=nil)
      dc.set_pen(@pen)
      dc.draw_lines(@points)
      if hit_dc
        hit_dc.set_pen(@hit_pen)
        hit_dc.draw_lines(@points)
      end
    end
   end

  class DrawObjectRectEllipse < DrawObject
    attr_accessor :x, :y, :width, :height

    def initialize(canvas, x, y, width, height, line_color='BLACK', line_style='SOLID', line_width=1, fill_color='NONE', fill_style='SOLID')
      super(canvas)
      set_shape(x, y, width, height)

      @line_color = line_color
      @line_style = line_style
      @line_width = line_width
      @fill_color = fill_color
      @fill_style = fill_style
      @hit_line_width = line_width > @min_hit_line_width ? line_width : @min_hit_line_width

      set_pen(line_color, line_style, line_width)
      set_brush(fill_color, fill_style)
    end

    def set_shape(x, y, width, height)
      @x = x
      @y = y
      @width = width
      @height = height
      @bounding_box = Wx::Rect.new(x, y, x+width, y+height)
      @canvas.bounding_box_dirty = true

      create_rgn
    end

    def set_up_draw(dc, hit_dc=nil)
      dc.set_pen(@pen)
      dc.set_brush(@brush)
      if hit_dc
        hit_dc.set_pen(@hit_pen)
        hit_dc.set_brush(@hit_brush)
      end
    end

    def create_rgn
      @rgn = Wx::Region.new(@x, @y, @width, @height)
    end
  end

  class DrawObjectRectangle < DrawObjectRectEllipse
    def draw(dc, hit_dc=nil)
      set_up_draw(dc, hit_dc)
      dc.draw_rectangle(@x,@y,@width,@height)
      hit_dc.draw_rectangle(@x,@y,@width,@height) if hit_dc
    end
  end

  class DrawObjectEllipse < DrawObjectRectEllipse
    def draw(dc, hit_dc=nil)
      set_up_draw(dc, hit_dc)
      dc.draw_ellipse(@x,@y,@width,@height)
      hit_dc.draw_ellipse(@x,@y,@width,@height) if hit_dc
    end

    def create_rgn
      @rgn = Wx::Region.create_ellipse_rgn(@x, @y, @width, @height)
    end
  end

  class DrawObjectCircle < DrawObjectEllipse
    def initialize(canvas, x, y, diameter, *args)
      @center = [x,y]
      super(canvas, x-diameter/2, y-diameter/2, diameter, diameter, *args)
    end

    def set_diameter(diameter)
      set_shape(@center[0]-diameter/2,@center[1]-diameter/2, diameter, diameter)
    end

    def create_rgn
      @rgn = Wx::Region.create_circle_rgn(@x, @y, @width)
    end
  end

  class DrawObjectText < DrawObject
#    @@screen_dc = Wx::ScreenDC.new
    ## store the function that shift the coords for drawing text. The
    ## "c" parameter is the correction for world coordinates, rather
    ## than pixel coords as the y axis is reversed
    @@shift_func_dict = {
      :POSITION_TL => proc {|x, y, w, h, world=0| [x, y]},
      :POSITION_TC => proc {|x, y, w, h, world=0| [x - w/2, y]} , 
      :POSITION_TR => proc {|x, y, w, h, world=0| [x - w, y]}, 
      :POSITION_CL => proc {|x, y, w, h, world=0| [x, y - h/2 + world*h]}, 
      :POSITION_CC => proc {|x, y, w, h, world=0| [x - w/2, y - h/2 + world*h]}, 
      :POSITION_CR => proc {|x, y, w, h, world=0| [x - w, y - h/2 + world*h]},
      :POSITION_BL => proc {|x, y, w, h, world=0| [x, y - h + 2*world*h]},
      :POSITION_BC => proc {|x, y, w, h, world=0| [x - w/2, y - h + 2*world*h]}, 
      :POSITION_BR => proc {|x, y, w, h, world=0| [x - w, y - h + 2*world*h]}
    }

    def initialize(canvas, text, x, y, size=12, color=:BLACK, backgroud_color=nil, family=Wx::MODERN, style=Wx::NORMAL, weight=Wx::NORMAL, unlerline=false, position=:POSITION_TL, font=nil)
      super(canvas)
      @text = text
      @x = x
      @y = y
      @size = size
      @color = Wx::Colour.new(color.to_s)
      @backgroud_color = backgroud_color

      if font
        set_font(font.get_point_size, 
                 font.get_family, 
                 font.get_style,
                 font.get_weight,
                 font.get_underline,
                 font.get_face_name)
      else
        set_font(size, family, style, weight, unlerline, '')
      end
      
      @bounding_box = Wx::Rect.new(x, y, x, y)
dc = Wx::WindowDC.new(canvas)
#      @text_width,@text_height = @@screen_dc.get_text_extent(text)
      @shift_func = @@shift_func_dict[position]

      create_rgn
    end

    def draw(dc, hit_dc=nil)
      @text_width,@text_height = dc.get_text_extent(text)
      dc.set_font(@font)
      dc.set_text_foreground(@color)
      if @backgroud_color
        dc.set_background_mode(Wx::SOLID)
        dc.set_text_background(@backgroud_color)
      else
        dc.set_background_mode(Wx::TRANSPARENT)
      end
      x,y = @shift_func.call(@x,@y,@text_width,@text_height)
      dc.draw_text(@text, x, y)

      if hit_dc
        hit_dc.set_pen(@hit_pen)
        hit_dc.set_brush(@hit_brush)
        hit_dc.draw_rectangle(@x,@y,@text_width,@text_height)
      end
    end

    def set_font(size, family, style, weight, underline, facename)
      @font = Wx::Font.new(size, family, style, weight, underline, facename)
    end

    def set_color(color)
      @color = color
    end

    def set_background_color(color)
      @backgroud_color = color
    end

    def create_rgn
      @rgn = Wx::Region.new(@x, @y, @text_width, @text_height)
    end
  end

  attr_accessor :bounding_box_dirty, :hit_dc

  def initialize(parent, id=-1, size=Wx::DEFAULT_SIZE, backgroud_color=Wx::WHITE)
    super(parent, -1, Wx::Point.new(0,0), size, Wx::SUNKEN_BORDER)

    set_background_colour(backgroud_color)
    @backgroud_brush = Wx::Brush.new(backgroud_color, Wx::SOLID)

    @draw_list = []
    @tags = {}
    @bounding_box = nil
    @hit_dict = {
      EVT_CANVAS_LEFT_DOWN    => {},
      EVT_CANVAS_LEFT_UP      => {},
      EVT_CANVAS_LEFT_DCLICK  => {},
      EVT_CANVAS_RIGHT_DOWN   => {},
      EVT_CANVAS_RIGHT_UP     => {},
      EVT_CANVAS_RIGHT_DCLICK => {},
      EVT_CANVAS_MOTION       => {},

      EVT_CANVAS_ENTER_OBJECT => {},
      EVT_CANVAS_LEAVE_OBJECT => {}
    }

    evt_left_down {|event| on_left_button_event_down(event)}
    evt_left_up {|event| on_left_button_event_up(event)}
    evt_left_dclick {|event| on_left_button_event_dclick(event)}
    evt_right_down {|event| on_right_button_event_down(event)}
    evt_right_up {|event| on_right_button_event_up(event)}
    evt_right_dclick {|event| on_right_button_event_dclick(event)}
    evt_motion {|event| on_event_motion(event)}
    evt_paint { on_paint }
    evt_size {|event| on_size(event)}
    evt_erase_background() {|event| }

    # called just to make sure everything is inilialized
    on_size(nil)

  end

  def raise_mouse_event(event, event_type)
    pt = event.get_position
    evt = CanvasMouseEvent.new(event_type, event, get_id(), pt)
    get_event_handler.process_event(evt)
  end

  def hit_object(object, hit_event)
    return nil unless object && (evt_obj_list = @hit_dict[hit_event])

    (object.tags + [object]).each {|tag|
      return evt_obj_list[tag] if evt_obj_list[tag]
    }
    nil
  end

  def hit_test(event, hit_event)
    evt_obj_list = @hit_dict[hit_event]
    return false unless evt_obj_list
    @hit_dc.get_pixel(event.get_x, event.get_y, @hit_color)
    return false unless @hit_color
    object = @hit_color_map[@hit_color.get_as_string(Wx::C2S_HTML_SYNTAX)]
    if object && (proc = hit_object(object, hit_event))
      proc.call(object, event)
      true
    else
      false
    end
  end

  def mouse_over_test(event)
    @hit_dc.get_pixel(event.get_x, event.get_y, @hit_color)
    old_object = @object_under_mouse
    object_callback_called = false
    object = @hit_color_map[@hit_color.get_as_string(Wx::C2S_HTML_SYNTAX)]
    if object && (proc_enter = hit_object(object, EVT_CANVAS_ENTER_OBJECT))
      if old_object == object # the mouse is still on the same object
        # do nothing
      else
        if old_object
          proc_leave = hit_object(old_object, EVT_CANVAS_LEAVE_OBJECT)
          proc_leave.call(old_object, event) if proc_leave
        end
        proc_enter.call(object, event)
        object_callback_called = true
      end
      @object_under_mouse = object
    elsif object && (proc_leave = hit_object(object, EVT_CANVAS_LEAVE_OBJECT))
      @object_under_mouse = object
    else
      @object_under_mouse = nil
      if old_object
        proc_leave = hit_object(old_object, EVT_CANVAS_LEAVE_OBJECT)
        proc_leave.call(old_object, event) if proc_leave
      end
    end
    object_callback_called
  end

  def convert_event_coords(event)
    xView, yView = get_view_start()
    xDelta, yDelta = get_scroll_pixels_per_unit()
    return event.get_x() + (xView * xDelta), event.get_y() + (yView * yDelta)
  end
    
  def on_left_button_event_down(event)
    event_type = EVT_CANVAS_LEFT_DOWN
    raise_mouse_event(event, event_type) unless hit_test(event, event_type)
  end

  def on_left_button_event_up(event)
    event_type = EVT_CANVAS_LEFT_UP
    raise_mouse_event(event, event_type) unless hit_test(event, event_type)
  end

  def on_left_button_event_dclick(event)
    event_type = EVT_CANVAS_LEFT_DCLICK
    raise_mouse_event(event, event_type) unless hit_test(event, event_type)
  end

  def on_right_button_event_down(event)
    event_type = EVT_CANVAS_RIGHT_DOWN
    raise_mouse_event(event, event_type) unless hit_test(event, event_type)
  end

  def on_right_button_event_up(event)
    event_type = EVT_CANVAS_RIGHT_UP
    raise_mouse_event(event, event_type) unless hit_test(event, event_type)
  end

  def on_right_button_event_dclick(event)
    event_type = EVT_CANVAS_RIGHT_DCLICK
    raise_mouse_event(event, event_type) unless hit_test(event, event_type)
  end

  def on_event_motion(event)
    event_type = EVT_CANVAS_MOTION
    raise_mouse_event(event, event_type) unless mouse_over_test(event)
  end

  def make_new_buffers
    @backgroud_dirty = true
    @bitmap = Wx::Bitmap.new(@size.width, @size.height)
    @mdc = Wx::MemoryDC.new
    @mdc.select_object(@bitmap)
    make_new_hit_dc
  end

  def make_new_hit_dc
    @hit_color = Wx::Colour.new(0,0,0)
    @hit_dc = Wx::MemoryDC.new
    @hit_bitmap = Wx::Bitmap.new(@size.width, @size.height)
    @hit_dc.select_object(@hit_bitmap)
    @hit_dc.set_background(Wx::BLACK_BRUSH)
  end

  def <<(object)
    @draw_list << object
    @hit_color_map ||= {}
    @hit_color_map[object.hit_color.get_as_string(Wx::C2S_HTML_SYNTAX)] = object
  end

  def on_size(event)
    @size = get_client_size
    make_new_buffers
    draw()
  end

  def on_paint
    paint {|dc| dc.blit(0, 0, @size.width, @size.height, @mdc, 0, 0)}
  end

  def draw(force=false)
    return if @size.width < 1 or @size.height < 1
    paint {|screen_dc|
      if @backgroud_dirty || force
        @mdc.set_background(@backgroud_brush)
        @mdc.clear()
        if @hit_dc
          @hit_dc.clear()
        end
        draw_objects(@mdc, @draw_list, screen_dc, @hit_dc)
        @background_dirty = false
      end

      screen_dc.blit(0, 0, @size.width, @size.height, @mdc, 0, 0)
    }
  end

  def remove_objects(*objects)
    objects.each {|obj|
      remove_object(obj)
    }
    @bounding_box_dirty = true
  end

  def remove_object(object)
    object.tags.each {|tag| @tags.delete tag }
    @draw_list.delete(object)
    @bounding_box_dirty = true
  end

  def clear_all()
    @draw_list = []
    @backgroud_dirty = true
    make_new_buffers
    @hit_dict = nil
  end

  def draw_objects(dc, draw_list, screen_dc, hit_dc=nil)
    dc.set_background(@backgroud_brush)
#    dc.begin_drawing
    draw_list.each {|object|
      object.draw(dc, hit_dc)
    }
#    screen_dc.blit(0, 0, @size.width, @size.height, dc, 0, 0)
#    dc.end_drawing
  end

  class << self
    def init_color
      @red = 0
      @green = 0
      @blue = 0
      @step = case Wx::Bitmap.new(1,1).get_depth()
              when 16
                8
              else                 # should be >= 24
                1
              end
    end

    def next_color
      init_color unless @red
      if @red < 255
        @red += @step
      elsif @green < 255
        @green += @step
      elsif @blue < 255
        @blue += @step
      end
      Wx::Colour.new(@red, @green, @blue)
    end
  end # end of class << self

  def create_line(*args)
    line = DrawObjectLine.new(self, *args)
  end

  def create_rectangle(*args)
    DrawObjectRectangle.new(self, *args)
  end

  def create_ellipse(*args)
    DrawObjectEllipse.new(self, *args)
  end

  def create_circle(*args)
    DrawObjectCircle.new(self, *args)
  end

  def create_text(*args)
    DrawObjectText.new(self, *args)
  end

  def get_object(tag_id)
    if tag_id.kind_of? DrawObject
      tag_id
    else
      obj = @draw_list.find {|obj| obj.tags.index(tag_id)}
      raise "invalid tag[#{tag_id}]" unless obj
    end
  end
  
  def bind(tag_id, event, &block)
    if block
      @hit_dict[event][tag_id] = block
    else
      @hit_dict[event].delete tag_id
    end
  end

  def add_tag(new_tag, obj)
    @tags[new_tag] ||= []
    @tags[new_tag] << obj unless @tags[new_tag].index(obj)
  end

  def add_tag_above(new_tag, tag_id)
  end

  def add_tag_below(new_tag, tag_id)
  end

  def add_tag_closest(new_tag, x, y, distance=0, tag_id=nil)
  end

  def add_tag_enclosed(new_tag, x1, y1, x2, y2)
  end

  def add_tag_overlapping(new_tag, x1, y1, x2, y2)
  end

  def add_tag_withtag(new_tag, tag_id)
    obj = get_object(tag_id)
    obj.add_tag(new_tag)
    add_tag(new_tag, obj)
  end

  def find_tags_above(tag_id)
  end

  def find_tags_below(tag_id)
  end

  def find_tas_closest(x, y, distance=0, tag_id=nil)
  end

  def find_tags_enclosed(x1, y1, x2, y2)
    rect = Wx::Rect.new(x1, y1, x2-x1, y2-y1)
    @draw_list.each {|obj|
      return (obj.tags + [obj]) if rect.contains(obj.bounding_box)
    }
    nil
  end

  def find_tags_overlapping(x1, y1, x2, y2)
    rect = Wx::Rect.new(x1, y1, x2-x1, y2-y1)
    @draw_list.each {|obj|
      return (obj.tags + [obj]) if obj.rgn.contains(rect)
    }
    nil
  end

  def find_tags_withtag(tag_id)
    gettags(tag_id)
  end

  def gettags(tag_id)
    obj = get_object(tag_id)
    obj.tags
  end

  def move(tag_id, dx, dy)
    obj = get_object(tag_id)
    obj.set_shape(obj.x+dx, obj.y+dy, obj.width, obj.height)
    draw
  end

  def coords(tag_id, x, y, width=nil, height=nil)
    obj = get_object(tag_id)
    width = obj.width unless width
    height = obj.height unless height
    obj.set_shape(x, y, width, height)
    draw
  end
end
