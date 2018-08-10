require 'wx'
require 'simulator'
require 'canvas'

module Simulator
    module Orgsim

        class ControlPanel < Wx::Panel
            def initialize(parent)
                super(parent, -1)
            end
        end

        class PropertyPanel < Wx::Panel
            def initialize(parent)
                super(parent, -1)
            end
        end

        class DesignStatusBar < Wx::StatusBar
            def initialize(parent)
                super(parent, -1)
                set_fields_count(3)
                self.set_status_text("status bar", 0)
            end
        end

        class UiDesign < Wx::Dialog
            def initialize(parent)
                super(parent, -1, "UI Design", Wx::DEFAULT_POSITION, Wx::Size.new(500,400))

                sizer = Wx::BoxSizer.new(Wx::HORIZONTAL)

                @controlPanel = ControlPanel.new(self)
                sizer.add(@controlPanel, 0, Wx::GROW)
                @canvas = Canvas.new(self)
                sizer.add(@canvas, 1, Wx::GROW)
                @propertyPanel = PropertyPanel.new(self)
                sizer.add(@PropertyPanel, 0, Wx::GROW)

                set_sizer(sizer)
                set_auto_layout(true)

                #        @sb = DesignStatusBar.new(self)
                #        set_status_bar(@sb)
            end
        end


    end # end of module Orgsim
end # end of module Simulator
