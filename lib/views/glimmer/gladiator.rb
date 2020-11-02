require 'fileutils'
require 'os'

require 'models/glimmer/gladiator/dir'
require 'models/glimmer/gladiator/file'
require 'models/glimmer/gladiator/command'

require 'views/glimmer/gladiator/text_editor'

Clipboard.implementation = Clipboard::Java
Clipboard.copy(Clipboard.paste) # pre-initialize library to avoid slowdown during use

module Glimmer
  # Gladiator (Glimmer Editor)
  class Gladiator
    include Glimmer::UI::CustomShell

    APP_ROOT = ::File.expand_path('../../../..', __FILE__)
    # TODO make sure COMMAND_KEY doesn't clash on Linux/Windows for CMD+CTRL shortcuts
    COMMAND_KEY = OS.mac? ? :command : :ctrl

    class << self
      attr_accessor :drag_and_drop
      attr_accessor :drag
    end
    
    ## Add options like the following to configure CustomShell by outside consumers
    #
    # options :title, :background_color
    # option :width, 320
    # option :height, 240
    option :project_dir_path
    
    def project_dir
      @project_dir ||= Dir.new(project_dir_path)
    end

    attr_reader :find_text, :tab_folder1, :tab_folder2, :filter_text, :rename_in_progress, :line_number_text, :file_tree
    attr_accessor :split_orientation, :current_tab_item, :current_tab_folder, :current_text_editor

    ## Uncomment before_body block to pre-initialize variables to use in body
    #
    #
    before_body {
      # TODO consider doing loading project files after displaying the GUI instead of holding it up before
      project_dir #pre-initialize directory
      at_exit do
        project_dir.selected_child&.write_raw_dirty_content
      end
      Display.setAppName('Gladiator')
      # make sure the display events are only hooked once if multiple gladiators are created
      unless defined?(@@display)
        @@display = display {
          on_swt_keydown { |key_event|
            focused_gladiator = display.focus_control.shell&.get_data('custom_shell')
            focused_gladiator.handle_display_shortcut(key_event) if !focused_gladiator.nil? && key_event.widget.shell == focused_gladiator&.swt_widget
          }
        }
      end

      @split_orientation = swt(:horizontal)
      @config_file_path = ::File.join(project_dir.path, '.gladiator')
      @config = {}
      load_config_ignore_paths
#       project_dir.all_children # pre-caches children
    }

    ## Uncomment after_body block to setup observers for widgets in body
    #
    after_body {
      observe(project_dir, 'children') do
        select_tree_item unless @rename_in_progress
      end
      observe(project_dir, 'selected_child') do |selected_file|
        if selected_file
          if Gladiator.drag && !@tab_folder2
            @tab_folder1 = @current_tab_folder
            @tab_folder_sash_form.content {
              @current_tab_folder = @tab_folder2 = tab_folder
              @current_tab_folder.swt_widget.setData('proxy', @current_tab_folder)
            }
          end
          select_tree_item unless @rename_in_progress
          found_tab_item = selected_tab_item
          if found_tab_item
            @current_tab_folder.swt_widget.setSelection(found_tab_item)
            @current_tab_item = found_tab_item.getData('proxy')
            @current_text_editor = found_tab_item.getData('text_editor')
            @current_tab_folder.swt_widget.setData('selected_tab_item', @current_tab_item)
          elsif selected_file
            @current_tab_folder.content {
              @current_tab_item = tab_item { |the_tab_item|
                text selected_file.name
                fill_layout :horizontal
                @current_text_editor = the_text_editor = text_editor(project_dir: project_dir, file: selected_file)
                @current_tab_folder.swt_widget.setData('selected_tab_item', @current_tab_item)
                @current_text_editor.text_proxy.content {
                  on_focus_gained {
                    tab_folder = the_text_editor.swt_widget.getParent.getParent
                    @current_tab_folder = tab_folder.getData('proxy')
                    @current_tab_item = the_tab_item
                    @current_text_editor = the_text_editor
                    @current_tab_folder.swt_widget.setData('selected_tab_item', @current_tab_item)
                    @current_tab_folder.swt_widget.setSelection(@current_tab_item.swt_tab_item)
                    project_dir.selected_child = @current_tab_item.swt_tab_item.getData('file')
                  }
                }
                on_swt_show {
                  @current_tab_item = the_tab_item
                  @current_text_editor = the_text_editor
                  @current_tab_folder = @current_tab_item.swt_widget.getParent.getData('proxy')
                  @current_tab_folder.swt_widget.setData('selected_tab_item', @current_tab_item)
                  @current_tab_folder.swt_widget.setSelection(@current_tab_item.swt_tab_item)
                  project_dir.selected_child = selected_file
                  async_exec {
                    @current_text_editor&.text_widget&.setFocus
                  }
                }
              }
              @current_tab_item.swt_tab_item.setData('file_path', selected_file.path)
              @current_tab_item.swt_tab_item.setData('file', selected_file)
              @current_tab_item.swt_tab_item.setData('text_editor', @current_text_editor)
              @current_tab_item.swt_tab_item.setData('proxy', @current_tab_item)
            }
            @current_tab_folder.swt_widget.setSelection(@current_tab_item.swt_tab_item)
            body_root.pack_same_size
          end
          @current_text_editor&.text_widget&.setFocus
        end
      end
      observe(project_dir, 'selected_child') do
        save_config
      end
      observe(project_dir, 'selected_child.caret_position') do
        save_config
      end
      observe(project_dir, 'selected_child.top_pixel') do
        save_config
      end
      load_config
    }

    ## Add widget content inside custom shell body
    ## Top-most widget must be a shell or another custom shell
    #
    body {
      shell {
        text "Gladiator - #{::File.expand_path(project_dir.path)}"
        minimum_size 520, 250
        size 1440, 900
        grid_layout(2, false)
        on_swt_show {
          swt_widget.setSize(@config[:shell_width], @config[:shell_height]) if @config[:shell_width] && @config[:shell_height]
          swt_widget.setLocation(@config[:shell_x], @config[:shell_y]) if @config[:shell_x] && @config[:shell_y]
          @loaded_config = true
        }
        on_swt_close {
          project_dir.selected_child&.write_dirty_content
        }
        on_widget_disposed {
          project_dir.selected_child&.write_dirty_content
        }
        on_control_resized {
          save_config
        }
        on_control_moved {
          save_config
        }
        on_shell_deactivated {
          @current_text_editor&.file&.write_dirty_content
        }

        menu_bar {
          menu {
            text '&File'

            menu_item {
              text 'New &Scratchpad'
              on_widget_selected {
                begin
                  project_dir.selected_child_path = ''
                rescue => e
                  pd e
                end
              }
            }
            menu_item(:separator)
            menu_item {
              text 'Open &Project...'
              on_widget_selected {
                open_project
              }
            }
          }
          menu {
            text '&View'
            menu {
              text '&Split'
              menu_item(:radio) {
                text '&Horizontal'
                selection bind(self, :split_orientation, on_read: ->(o) { o == swt(:horizontal)}, on_write: ->(b) { b ? swt(:horizontal) : swt(:vertical)})
              }
              menu_item(:radio) {
                text '&Vertical'
                selection bind(self, :split_orientation, on_read: ->(o) { o == swt(:vertical)}, on_write: ->(b) { b ? swt(:vertical) : swt(:horizontal)})
              }
            }
          }
          menu {
            text '&Run'
#             menu_item {
#               text 'Launch Glimmer &App'
#               on_widget_selected {
#                 parent_path = project_dir.path
##                 current_directory_name = ::File.basename(parent_path)
##                 assumed_shell_script = ::File.join(parent_path, 'bin', current_directory_name)
##                 assumed_shell_script = ::Dir.glob(::File.join(parent_path, 'bin', '*')).detect {|f| ::File.file?(f) && !::File.read(f).include?('#!/usr/bin/env')} if !::File.exist?(assumed_shell_script)
##                 load assumed_shell_script
#                 FileUtils.cd(parent_path) do
#                   system 'glimmer run'
#                 end
#               }
#             }
            menu_item {
              text '&Ruby'
              on_widget_selected {
                project_dir.selected_child.run
              }
            }
          }
        }

        composite {
          grid_layout 1, false
          layout_data(:fill, :fill, false, true) {
            width_hint 300
          }
          @filter_text = text {
            layout_data :fill, :center, true, false
            text bind(project_dir, 'filter')
            on_key_pressed { |key_event|
              if key_event.keyCode == swt(:tab) ||
                  key_event.keyCode == swt(:cr) ||
                  key_event.keyCode == swt(:arrow_up) ||
                  key_event.keyCode == swt(:arrow_down)
                @list.swt_widget.select(0) if @list.swt_widget.getSelectionIndex() == -1
                @list.swt_widget.setFocus
              end
            }
          }
          composite {
            fill_layout(:vertical) {
              spacing 5
            }
            layout_data(:fill, :fill, true, true)
            @list = list(:border, :h_scroll, :v_scroll) {
              #visible bind(self, 'project_dir.filter') {|f| !!f}
              selection bind(project_dir, :filtered_path)
              on_mouse_up {
                project_dir.selected_child_path = @list.swt_widget.getSelection.first
              }
              on_key_pressed { |key_event|
                if Glimmer::SWT::SWTProxy.include?(key_event.keyCode, :cr)
                  project_dir.selected_child_path = @list.swt_widget.getSelection.first
                  @current_text_editor&.text_widget&.setFocus
                end
              }
              drag_source(DND::DROP_COPY) {
                transfer [TextTransfer.getInstance].to_java(Transfer)
                on_drag_set_data { |event|
                  Gladiator.drag = true
                  list = event.widget.getControl
                  event.data = list.getSelection.first
                }
              }
            }
            @file_tree = tree(:virtual, :border, :h_scroll, :v_scroll) {
              #visible bind(self, 'project_dir.filter') {|f| !f}
              items bind(self, :project_dir), tree_properties(children: :children, text: :name)
              drag_source(DND::DROP_COPY) {
                transfer [TextTransfer.getInstance].to_java(Transfer)
                on_drag_set_data { |event|
                  Gladiator.drag = true
                  tree = event.widget.getControl
                  tree_item = tree.getSelection.first
                  event.data = tree_item.getData.path
                }
              }
              menu {
                @open_menu_item = menu_item {
                  text 'Open'
                  on_widget_selected {
                    project_dir.selected_child_path = extract_tree_item_path(@file_tree.swt_widget.getSelection.first)
                  }
                }
                menu_item(:separator)
                menu_item {
                  text 'Delete'
                  on_widget_selected {
                    tree_item = @file_tree.swt_widget.getSelection.first
                    delete_tree_item(tree_item)
                  }
                }
                menu_item {
                  text 'Refresh'
                  on_widget_selected {
                    project_dir.refresh
                  }
                }
                menu_item {
                  text 'Rename'
                  on_widget_selected {
                    rename_selected_tree_item
                  }
                }
                menu_item {
                  text 'New Directory'
                  on_widget_selected {
                    add_new_directory_to_selected_tree_item
                  }
                }
                menu_item {
                  text 'New File'
                  on_widget_selected {
                    add_new_file_to_selected_tree_item
                  }
                }
              }
              on_swt_menudetect { |event|
                path = extract_tree_item_path(@file_tree.swt_widget.getSelection.first)
                @open_menu_item.swt_widget.setEnabled(!::Dir.exist?(path)) if path
              }
              on_mouse_up {
                if Gladiator.drag_and_drop
                  Gladiator.drag_and_drop = false
                else
                  project_dir.selected_child_path = extract_tree_item_path(@file_tree.swt_widget.getSelection&.first)
                  @current_text_editor&.text_widget&.setFocus
                end
              }
              on_key_pressed { |key_event|
                if Glimmer::SWT::SWTProxy.include?(key_event.keyCode, :cr)
                  project_dir.selected_child_path = extract_tree_item_path(@file_tree.swt_widget.getSelection&.first)
                  @current_text_editor&.text_widget&.setFocus
                end
              }
              on_paint_control {
                root_item = @file_tree.swt_widget.getItems.first
                if root_item && !root_item.getExpanded
                  root_item.setExpanded(true)
                end
              }
            }
          }

          # TODO see if you could replace some of this with Glimmer DSL/API syntax
          @file_tree_editor = TreeEditor.new(@file_tree.swt_widget);
          @file_tree_editor.horizontalAlignment = swt(:left);
          @file_tree_editor.grabHorizontal = true;
          @file_tree_editor.minimumHeight = 20;

        }
        @editor_container = composite {
          grid_layout 1, false
          layout_data :fill, :fill, true, true
          composite {
            grid_layout 3, false

            # row 1

            label {
              text 'File:'
            }

            @file_path_label = styled_text(:none) {
              layout_data(:fill, :fill, true, false) {
                horizontal_span 2
              }
              background color(:widget_background)
              editable false
              caret nil
              text bind(project_dir, 'selected_child.path')
              on_mouse_up {
                @file_path_label.swt_widget.selectAll
              }
              on_focus_lost {
                @file_path_label.swt_widget.setSelection(0, 0)
              }
            }

            # row 2

            label {
              text 'Line:'
            }
            @line_number_text = text {
              layout_data(:fill, :fill, true, false) {
                minimum_width 400
              }
              text bind(project_dir, 'selected_child.line_number', on_read: :to_s, on_write: :to_i)
              on_key_pressed { |key_event|
                if key_event.keyCode == swt(:cr)
                  @current_text_editor&.text_widget&.setFocus
                end
              }
              on_verify_text { |event|
                event.doit = !event.text.match(/^\d*$/).to_a.empty?
              }
            }
            label

            # row 3

            label {
              text 'Find:'
            }
            @find_text = text {
              layout_data(:fill, :center, true, false) {
                minimum_width 400
              }
              text bind(project_dir, 'selected_child.find_text')
              on_key_pressed { |key_event|
                if key_event.stateMask == swt(COMMAND_KEY) && key_event.keyCode == swt(:cr)
                  project_dir.selected_child.case_sensitive = !project_dir.selected_child.case_sensitive
                  project_dir.selected_child&.find_next
                end
                if key_event.keyCode == swt(:cr)
                  project_dir.selected_child&.find_next
                end
              }
            }
            composite {
              row_layout
              button(:check) {
                selection bind(project_dir, 'selected_child.case_sensitive')
                on_key_pressed { |key_event|
                  if key_event.keyCode == swt(:cr)
                    project_dir.selected_child&.find_next
                  end
                }
              }
              label {
                text 'Case-sensitive'
              }
            }

            # row 4

            label {
              text 'Replace:'
            }
            @replace_text = text {
              layout_data(:fill, :fill, true, false) {
                minimum_width 300
              }
              text bind(project_dir, 'selected_child.replace_text')
              on_focus_gained {
                project_dir.selected_child&.ensure_find_next
              }
              on_key_pressed { |key_event|
                if key_event.keyCode == swt(:cr)
                  if project_dir.selected_child
                    Command.do(project_dir.selected_child, :replace_next!)
                  end
                end
              }
            }
            label
          }
          @tab_folder_sash_form = sash_form {
            layout_data(:fill, :fill, true, true) {
              width_hint 640
              height_hint 480
            }
            sash_width 10
            orientation bind(self, :split_orientation)
            @current_tab_folder = tab_folder {
              drag_source(DND::DROP_COPY) {
                transfer [TextTransfer.getInstance].to_java(Transfer)
                event_data = nil
                on_drag_start {|event|
                  Gladiator.drag = true
                  tab_folder = event.widget.getControl
                  tab_item = tab_folder.getItem(Point.new(event.x, event.y))
                  event_data = tab_item.getData('file_path')
                }
                on_drag_set_data { |event|
                  event.data = event_data
                }
              }
            }
            @current_tab_folder.swt_widget.setData('proxy', @current_tab_folder)
          }
        }
      }
    }
    
    def load_config_ignore_paths
      # TODO eliminate duplication with load_config
      if ::File.exists?(@config_file_path)
        config_yaml = ::File.read(@config_file_path)
        return if config_yaml.to_s.strip.empty?
        @config = YAML.load(config_yaml)
        project_dir.ignore_paths = @config[:ignore_paths] if @config[:ignore_paths]
        project_dir.ignore_paths ||= ['packages', 'tmp']
      else
        @loaded_config = true
      end
    end

    def load_config
      if ::File.exists?(@config_file_path)
        config_yaml = ::File.read(@config_file_path)
        return if config_yaml.to_s.strip.empty?
        @config = YAML.load(config_yaml)
        project_dir.ignore_paths = @config[:ignore_paths] if @config[:ignore_paths]
        project_dir.ignore_paths ||= ['packages', 'tmp']
        open_file_paths1 = @config[:open_file_paths1] || @config[:open_file_paths]
        open_file_paths2 = @config[:open_file_paths2]
        open_file_paths1.to_a.each do |file_path|
          project_dir.selected_child_path = file_path
        end
        # TODO replace the next line with one that selects the visible tab
        project_dir.selected_child_path = @config[:selected_child_path] if @config[:selected_child_path] && open_file_paths1.to_a.include?(@config[:selected_child_path])
        Gladiator.drag = true
        open_file_paths2.to_a.each do |file_path|
          project_dir.selected_child_path = file_path
        end
        # TODO replace the next line with one that selects the visible tab
        project_dir.selected_child_path = @config[:selected_child_path] if @config[:selected_child_path] && open_file_paths2.to_a.include?(@config[:selected_child_path])
        Gladiator.drag = false
        project_dir.selected_child&.caret_position  = project_dir.selected_child&.caret_position_for_caret_position_start_of_line(@config[:caret_position].to_i) if @config[:caret_position]
        project_dir.selected_child&.top_pixel = @config[:top_pixel].to_i if @config[:top_pixel]
      else
        @loaded_config = true
      end
    end

    def save_config
      return unless @loaded_config
      child = project_dir.selected_child
      return if child.nil?
      tab_folder1 = @tab_folder1 || @current_tab_folder
      tab_folder2 = @tab_folder2
      open_file_paths1 = tab_folder1&.swt_widget&.items.to_a.map {|i| i.get_data('file_path')}
      open_file_paths2 = tab_folder2&.swt_widget&.items.to_a.map {|i| i.get_data('file_path')}
      @config = {
        selected_child_path: child.path,
        caret_position: child.caret_position,
        top_pixel: child.top_pixel,
        shell_width: swt_widget&.getBounds&.width,
        shell_height: swt_widget&.getBounds&.height,
        shell_x: swt_widget&.getBounds&.x,
        shell_y: swt_widget&.getBounds&.y,
        open_file_paths1: open_file_paths1,
        open_file_paths2: open_file_paths2,
        ignore_paths: project_dir.ignore_paths
      }
      config_yaml = YAML.dump(@config)
      ::File.write(@config_file_path, config_yaml) unless config_yaml.to_s.empty?
    rescue => e
      puts e.full_message
    end

    def close_tab_folder
      if @tab_folder2 && !selected_tab_item
        if @current_tab_folder == @tab_folder2
          @tab_folder2.swt_widget.dispose
          @current_tab_folder = @tab_folder1
        else
          @tab_folder1.swt_widget.dispose
          @current_tab_folder = @tab_folder1 = @tab_folder2
        end
        @tab_folder2 = nil

        @current_tab_item = @current_tab_folder.swt_widget.getData('selected_tab_item')
        @current_text_editor = @current_tab_item.swt_tab_item.getData('text_editor')
        project_dir.selected_child = @current_tab_item.swt_tab_item.getData('file')

        body_root.pack_same_size
      end
    end

    def find_tab_item(file_path)
      @current_tab_folder.swt_widget.getItems.detect { |ti| ti.getData('file_path') == file_path }
    end

    def selected_tab_item
      find_tab_item(project_dir.selected_child&.path)
    end

    def other_tab_items
      @current_tab_folder.swt_widget.getItems.reject { |ti| ti.getData('file_path') == project_dir.selected_child&.path }
    end

    def extract_tree_item_path(tree_item)
      return if tree_item.nil?
      if tree_item.getParentItem
        ::File.join(extract_tree_item_path(tree_item.getParentItem), tree_item.getText)
      else
        project_dir.path
      end
    end

    def select_tree_item
      return unless project_dir.selected_child&.name
      tree_items_to_select = @file_tree.depth_first_search { |ti| ti.getData.path == project_dir.selected_child.path }
      @file_tree.swt_widget.setSelection(tree_items_to_select)
    end

    def delete_tree_item(tree_item)
      return if tree_item.nil?
      file = tree_item.getData
      parent_path = ::File.dirname(file.path)
      file.delete! # TODO consider supporting command undo/redo
      project_dir.refresh(async: false)
      parent_tree_item = @file_tree.depth_first_search {|ti| ti.getData.path == parent_path}.first
      @file_tree.swt_widget.showItem(parent_tree_item)
      parent_tree_item.setExpanded(true)
      # TODO close text editor tab
      found_tab_item = find_tab_item(file.path)
      if found_tab_item
        project_dir.selected_child_path_history.delete(found_tab_item.getData('file_path'))
        found_tab_item.getData('proxy')&.dispose
      end
    rescue => e
      puts e.full_message
    end

    def add_new_directory_to_selected_tree_item
      project_dir.pause_refresh
      tree_item = @file_tree.swt_widget.getSelection.first
      directory_path = extract_tree_item_path(tree_item)
      return if directory_path.nil?
      if !::Dir.exist?(directory_path)
        tree_item = tree_item.getParentItem
        directory_path = ::File.dirname(directory_path)
      end
      new_directory_path = ::File.expand_path(::File.join(directory_path, 'new_directory'))
      FileUtils.mkdir_p(new_directory_path)
      project_dir.refresh(async: false, force: true)
      new_tree_item = @file_tree.depth_first_search {|ti| ti.getData.path == new_directory_path}.first
      @file_tree.swt_widget.showItem(new_tree_item)
      rename_tree_item(new_tree_item)
    end

    def add_new_file_to_selected_tree_item
      project_dir.pause_refresh
      tree_item = @file_tree.swt_widget.getSelection.first
      directory_path = extract_tree_item_path(tree_item)
      if !::Dir.exist?(directory_path)
        tree_item = tree_item.getParentItem
        directory_path = ::File.dirname(directory_path)
      end
      new_file_path = ::File.expand_path(::File.join(directory_path, 'new_file'))
      FileUtils.touch(new_file_path)
      # TODO look into refreshing only the parent directory to avoid slowdown
      project_dir.refresh(async: false, force: true)
      new_tree_item = @file_tree.depth_first_search {|ti| ti.getData.path == new_file_path}.first
      @file_tree.swt_widget.showItem(new_tree_item)
      rename_tree_item(new_tree_item, true)
    end

    def rename_selected_tree_item
      project_dir.pause_refresh
      tree_item = @file_tree.swt_widget.getSelection.first
      rename_tree_item(tree_item)
    end

    def rename_tree_item(tree_item, new_file = false)
      original_file = tree_item.getData
      current_file = project_dir.selected_child_path == original_file.path
      found_tab_item = find_tab_item(original_file.path)
      found_text_editor = found_tab_item&.getData('text_editor')
      @file_tree.edit_tree_item(
        tree_item,
        after_write: -> (edited_tree_item) {
          file = edited_tree_item.getData
          file_path = file.path
          file.name
          if new_file
            project_dir.selected_child_path = file_path
          else
            found_text_editor&.file = file
            found_tab_item&.setData('file', file)
            found_tab_item&.setData('file_path', file.path)
            found_tab_item&.setText(file.name)
            body_root.pack_same_size
            if current_file
              project_dir.selected_child_path = file_path
            else
              selected_tab_item&.getData('text_editor')&.text_widget&.setFocus
            end
          end
          project_dir.resume_refresh
        },
        after_cancel: -> {
          project_dir.resume_refresh
        }
      )
    end

    def extract_char(event)
      event.keyCode.chr
    rescue => e
      nil
    end
    
    def open_project
      selected_directory = directory_dialog.open
      @progress_bar_shell = shell(body_root) {
        text 'Opening Project'
        fill_layout(:vertical) {
          margin_width 15
          margin_height 15
          spacing 5
        }
        label(:center) {
          text "Opening Project: #{::File.basename(selected_directory)}"
          font height: 20
        }
#         @progress_bar = progress_bar(:horizontal, :indeterminate)
      }
      Thread.new {
        async_exec {
          @progress_bar_shell.open
        }
      }
      Thread.new {
        async_exec {
          gladiator(project_dir_path: selected_directory) {
            on_swt_show {
              @progress_bar_shell.close
            }
          }.open if selected_directory
        }
      }
    end
    
    def handle_display_shortcut(key_event)
      if key_event.stateMask == swt(COMMAND_KEY) && extract_char(key_event) == 'f'
        if current_text_editor&.text_widget&.getSelectionText && current_text_editor&.text_widget&.getSelectionText&.size.to_i > 0
          find_text.swt_widget.setText current_text_editor.text_widget.getSelectionText
        end
        find_text.swt_widget.selectAll
        find_text.swt_widget.setFocus
      elsif Glimmer::SWT::SWTProxy.include?(key_event.stateMask, COMMAND_KEY, :shift) && extract_char(key_event) == 'c'
        Clipboard.copy(project_dir.selected_child.path)
      elsif Glimmer::SWT::SWTProxy.include?(key_event.stateMask, COMMAND_KEY, :shift) && extract_char(key_event) == 'g'
        project_dir.selected_child.find_previous
      elsif Glimmer::SWT::SWTProxy.include?(key_event.stateMask, COMMAND_KEY, :shift) && extract_char(key_event) == 'p'
        open_project
      elsif Glimmer::SWT::SWTProxy.include?(key_event.stateMask, COMMAND_KEY, :shift) && extract_char(key_event) == 's'
        project_dir.selected_child_path = '' # scratchpad
      elsif Glimmer::SWT::SWTProxy.include?(key_event.stateMask, COMMAND_KEY, :shift) && extract_char(key_event) == 'w'
        current_tab_folder.swt_widget.getItems.each do |tab_item|
          project_dir.selected_child_path_history.delete(tab_item.getData('file_path'))
          tab_item.getData('proxy')&.dispose
        end
        close_tab_folder
        self.current_tab_item = self.current_text_editor = project_dir.selected_child = nil
        filter_text.swt_widget.selectAll
        filter_text.swt_widget.setFocus
      elsif Glimmer::SWT::SWTProxy.include?(key_event.stateMask, COMMAND_KEY, :alt) && extract_char(key_event) == 'w'
        other_tab_items.each do |tab_item|
          project_dir.selected_child_path_history.delete(tab_item.getData('file_path'))
          tab_item.getData('proxy')&.dispose
        end
      elsif key_event.stateMask == swt(COMMAND_KEY) && extract_char(key_event) == 'w'
        if selected_tab_item
          project_dir.selected_child_path_history.delete(project_dir.selected_child.path)
          selected_tab_item.getData('proxy')&.dispose
          close_tab_folder
          if selected_tab_item.nil?
            self.current_tab_item = self.current_text_editor = project_dir.selected_child = nil
            filter_text.swt_widget.selectAll
            filter_text.swt_widget.setFocus
          else
            current_text_editor&.text_widget&.setFocus
          end
        end
      elsif Glimmer::SWT::SWTProxy.include?(key_event.stateMask, COMMAND_KEY, :shift) && extract_char(key_event) == 'o'
        self.split_orientation = split_orientation == swt(:horizontal) ? swt(:vertical) : swt(:horizontal)
      elsif Glimmer::SWT::SWTProxy.include?(key_event.stateMask, COMMAND_KEY, :shift) && extract_char(key_event) == ']'
        current_tab_folder.swt_widget.setSelection((current_tab_folder.swt_widget.getSelectionIndex() + 1) % current_tab_folder.swt_widget.getItemCount) if current_tab_folder.swt_widget.getItemCount > 0
        current_text_editor&.text_widget&.setFocus
      elsif Glimmer::SWT::SWTProxy.include?(key_event.stateMask, COMMAND_KEY, :shift) && extract_char(key_event) == '['
        current_tab_folder.swt_widget.setSelection((current_tab_folder.swt_widget.getSelectionIndex() - 1) % current_tab_folder.swt_widget.getItemCount) if current_tab_folder.swt_widget.getItemCount > 0
        current_text_editor&.text_widget&.setFocus
      elsif Glimmer::SWT::SWTProxy.include?(key_event.stateMask, COMMAND_KEY, :ctrl) && extract_char(key_event) == ']'
        if tab_folder2
          if current_tab_folder == tab_folder1
            self.current_tab_folder = tab_folder2
          else
            self.current_tab_folder = tab_folder1
          end
          self.current_tab_item = current_tab_folder.swt_widget.getData('selected_tab_item')
          self.project_dir.selected_child = current_tab_item&.swt_tab_item&.getData('file')
          current_tab_item&.swt_tab_item&.getData('text_editor')&.text_widget&.setFocus
        end
      elsif Glimmer::SWT::SWTProxy.include?(key_event.stateMask, COMMAND_KEY, :ctrl) && extract_char(key_event) == '['
        if tab_folder2
          if current_tab_folder == tab_folder2
            self.current_tab_folder = tab_folder1
          else
            self.current_tab_folder = tab_folder2
          end
          self.current_tab_item = current_tab_folder.swt_widget.getData('selected_tab_item')
          self.project_dir.selected_child = current_tab_item&.swt_tab_item&.getData('file')
          current_tab_item&.swt_tab_item&.getData('text_editor')&.text_widget&.setFocus
        end
      elsif Glimmer::SWT::SWTProxy.include?(key_event.stateMask, COMMAND_KEY) && extract_char(key_event) == '1'
        current_tab_folder.swt_widget.setSelection(0) if current_tab_folder.swt_widget.getItemCount >= 1
        current_text_editor&.text_widget&.setFocus
      elsif Glimmer::SWT::SWTProxy.include?(key_event.stateMask, COMMAND_KEY) && extract_char(key_event) == '2'
        current_tab_folder.swt_widget.setSelection(1) if current_tab_folder.swt_widget.getItemCount >= 2
        current_text_editor&.text_widget&.setFocus
      elsif Glimmer::SWT::SWTProxy.include?(key_event.stateMask, COMMAND_KEY) && extract_char(key_event) == '3'
        current_tab_folder.swt_widget.setSelection(2) if current_tab_folder.swt_widget.getItemCount >= 3
        current_text_editor&.text_widget&.setFocus
      elsif Glimmer::SWT::SWTProxy.include?(key_event.stateMask, COMMAND_KEY) && extract_char(key_event) == '4'
        current_tab_folder.swt_widget.setSelection(3) if current_tab_folder.swt_widget.getItemCount >= 4
        current_text_editor&.text_widget&.setFocus
      elsif Glimmer::SWT::SWTProxy.include?(key_event.stateMask, COMMAND_KEY) && extract_char(key_event) == '5'
        current_tab_folder.swt_widget.setSelection(4) if current_tab_folder.swt_widget.getItemCount >= 5
        current_text_editor&.text_widget&.setFocus
      elsif Glimmer::SWT::SWTProxy.include?(key_event.stateMask, COMMAND_KEY) && extract_char(key_event) == '6'
        current_tab_folder.swt_widget.setSelection(5) if current_tab_folder.swt_widget.getItemCount >= 6
        current_text_editor&.text_widget&.setFocus
      elsif Glimmer::SWT::SWTProxy.include?(key_event.stateMask, COMMAND_KEY) && extract_char(key_event) == '7'
        current_tab_folder.swt_widget.setSelection(6) if current_tab_folder.swt_widget.getItemCount >= 7
        current_text_editor&.text_widget&.setFocus
      elsif Glimmer::SWT::SWTProxy.include?(key_event.stateMask, COMMAND_KEY) && extract_char(key_event) == '8'
        current_tab_folder.swt_widget.setSelection(7) if current_tab_folder.swt_widget.getItemCount >= 8
        current_text_editor&.text_widget&.setFocus
      elsif Glimmer::SWT::SWTProxy.include?(key_event.stateMask, COMMAND_KEY) && extract_char(key_event) == '9'
        current_tab_folder.swt_widget.setSelection(current_tab_folder.swt_widget.getItemCount - 1) if current_tab_folder.swt_widget.getItemCount > 0
        current_text_editor&.text_widget&.setFocus
      elsif Glimmer::SWT::SWTProxy.include?(key_event.stateMask, COMMAND_KEY) && extract_char(key_event) == 'g'
        project_dir.selected_child.find_next
      elsif Glimmer::SWT::SWTProxy.include?(key_event.stateMask, COMMAND_KEY) && extract_char(key_event) == 'l'
        line_number_text.swt_widget.selectAll
        line_number_text.swt_widget.setFocus
      elsif key_event.stateMask == swt(COMMAND_KEY) && extract_char(key_event) == 'r'
        filter_text.swt_widget.selectAll
        filter_text.swt_widget.setFocus
      elsif key_event.stateMask == swt(COMMAND_KEY) && extract_char(key_event) == 't'
        select_tree_item unless rename_in_progress
        file_tree.swt_widget.setFocus
      elsif key_event.keyCode == swt(:esc)
        if current_text_editor
          project_dir.selected_child_path = current_text_editor.file.path
          current_text_editor&.text_widget&.setFocus
        end
      end
    end
  end
end
