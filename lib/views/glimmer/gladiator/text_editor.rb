module Glimmer
  class Gladiator
    class TextEditor
      include Glimmer::UI::CustomWidget

      options :file, :project_dir

      attr_reader :text_proxy, :text_widget
      
      before_body {
        @is_code_file = file.path.nil? || file.path.end_with?('.rb')
        @text_widget = @is_code_file ? 'code_text' : 'styled_text'
      }

      after_body {
        @text_widget = @text.swt_widget
        @text_proxy = @text
      }
      
      body {
        composite {
          layout_data :fill, :fill, true, true
          grid_layout 2, false
          @line_numbers_text = styled_text(:multi, :border) {
            layout_data(:right, :fill, false, true)
            font name: 'Consolas', height: OS.mac? ? 15 : 12
            background color(:widget_background)
            foreground rgb(0, 0, 250)
            text bind(file, 'line_numbers_content')
            top_pixel bind(file, 'top_pixel', read_only: true)
            top_margin 5
            right_margin 5
            bottom_margin 5
            left_margin 5
            on_focus_gained {
              @text&.swt_widget.setFocus
            }
            on_key_pressed {
              @text&.swt_widget.setFocus
            }
            on_mouse_up {
              @text&.swt_widget.setFocus
            }
          }
          
          @text = send(@text_widget) {
            layout_data :fill, :fill, true, true
            font name: 'Consolas', height: OS.mac? ? 15 : 12
            foreground rgb(75, 75, 75)
            text bind(file, :content)
            focus true
            selection bind(file, :selection)
            top_pixel bind(file, 'top_pixel')
            drop_target(DND::DROP_COPY) {
              transfer [TextTransfer.getInstance].to_java(Transfer)
              on_drag_enter { |event|
                event.detail = DND::DROP_COPY
              }
              on_drop { |event|
                Gladiator.drag_and_drop = true
                project_dir.selected_child = nil
                project_dir.selected_child_path = event.data
                Gladiator.drag = false
              }
            }
            
            on_focus_lost {
              file&.write_dirty_content
            }
            on_verify_key { |key_event|
              if (Glimmer::SWT::SWTProxy.include?(key_event.stateMask, COMMAND_KEY, :shift) && extract_char(key_event) == 'z') || (key_event.stateMask == swt(COMMAND_KEY) && extract_char(key_event) == 'y')
                key_event.doit = !Command.redo(file)
              elsif Glimmer::SWT::SWTProxy.include?(key_event.stateMask, COMMAND_KEY, :shift) && extract_char(key_event) == 'r'
                project_dir.selected_child.write_dirty_content
                begin
                  if project_dir.selected_child.path.nil?
                    eval project_dir.selected_child.content
                  else
                    load project_dir.selected_child.path
                  end
                rescue => e
                  puts e.full_message
                end
              elsif key_event.stateMask == swt(COMMAND_KEY) && extract_char(key_event) == 'z'
                key_event.doit = !Command.undo(file)
              elsif key_event.stateMask == swt(COMMAND_KEY) && extract_char(key_event) == 'a'
                key_event.widget.selectAll
              elsif !OS.windows? && key_event.stateMask == swt(:ctrl) && extract_char(key_event) == 'a'
                Command.do(file, :start_of_line)
                key_event.doit = false
              elsif !OS.windows? && key_event.stateMask == swt(:ctrl) && extract_char(key_event) == 'e'
                Command.do(file, :end_of_line)
                key_event.doit = false
              elsif key_event.stateMask == swt(COMMAND_KEY) && extract_char(key_event) == '/'
                Command.do(file, :comment_line!)
                key_event.doit = false
              elsif key_event.stateMask == swt(COMMAND_KEY) && extract_char(key_event) == 'k'
                Command.do(file, :kill_line!)
                key_event.doit = false
              elsif key_event.stateMask == swt(COMMAND_KEY) && extract_char(key_event) == 'd'
                Command.do(file, :duplicate_line!)
                key_event.doit = false
              elsif key_event.stateMask == swt(COMMAND_KEY) && extract_char(key_event) == '['
                Command.do(file, :outdent!)
                key_event.doit = false
              elsif key_event.stateMask == swt(COMMAND_KEY) && extract_char(key_event) == ']'
                Command.do(file, :indent!)
                key_event.doit = false
              elsif Glimmer::SWT::SWTProxy.include?(key_event.stateMask, COMMAND_KEY, :shift) && key_event.keyCode == swt(:cr)
                Command.do(file, :prefix_new_line!)
                key_event.doit = false
              elsif key_event.stateMask == swt(COMMAND_KEY) && key_event.keyCode == swt(:cr)
                Command.do(file, :insert_new_line!)
                key_event.doit = false
              elsif key_event.keyCode == swt(:page_up)
                file.page_up
                key_event.doit = false
              elsif key_event.keyCode == swt(:page_down)
                file.page_down
                key_event.doit = false
              elsif key_event.keyCode == swt(:home)
                file.home
                key_event.doit = false
              elsif key_event.keyCode == swt(:end)
                file.end
                key_event.doit = false
              elsif key_event.stateMask == swt(COMMAND_KEY) && key_event.keyCode == swt(:arrow_up)
                Command.do(file, :move_up!)
                key_event.doit = false
              elsif key_event.stateMask == swt(COMMAND_KEY) && key_event.keyCode == swt(:arrow_down)
                Command.do(file, :move_down!)
                key_event.doit = false
              end
            }
            on_verify_text { |verify_event|
              # TODO convert these into File commands to support Undo/Redo
              case verify_event.text
              when "\n"
                if file.selection_count.to_i == 0
                  verify_event.text += file.current_line_indentation
                end
              when "\t"
                if file.selection_count.to_i > 0
                  Command.do(file, :indent!)
                  verify_event.doit = false
                else
                  verify_event.text = '  '
                end
              end
            }
          }
        }
      }
            
      def extract_char(event)
        event.keyCode.chr
      rescue => e
        nil
      end
                                                                                                                                                                                                                                                                                                      
    end
  end
end
                                              