/* window.vala
 *
 * Copyright 2022 Hypatia Developers
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

namespace Hypatia {
	public class Window : Adw.ApplicationWindow {

	    public signal void search_requested (string term);

	    private InstantAnswersBox answers_box;
	    private DictionaryBox dictionary_box;
	    private WikipediaBox wikipedia_box;

	    private Adw.Carousel carousel;
	    private Gtk.ScrolledWindow answers_scrolled;

	    private Gtk.Entry search_entry;

	    private Gtk.Spinner loading_spinner;

	    private bool new_start = true;

		public Window (Hypatia.Application app) {
			Object(application: app);

			var style_manager = Adw.StyleManager.get_default();
            style_manager.color_scheme = Adw.ColorScheme.PREFER_LIGHT;

			this.set_default_size(600, 350);

            var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 12);
            this.set_content(box);

            var header = new Adw.HeaderBar();
            header.get_style_context().add_class("flat");
            box.append(header);

			var title_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
            header.set_title_widget(title_box);

			var welcome_box = new WelcomeBox();
			answers_box = new InstantAnswersBox();
			dictionary_box = new DictionaryBox();
			wikipedia_box = new WikipediaBox();

			var share_button = new Gtk.Button.from_icon_name("emblem-shared-symbolic");
			var share_popover = new Gtk.Popover();

			var tweet_button = new Gtk.Button.with_label("Share article via Tweet");
			tweet_button.clicked.connect(() => {

                string encoded_text = """Look%20what%20I%20found%20on%20Wikipedia%20using%20%23Hypatia%3A%20""";
                string url = "https://twitter.com/intent/tweet?text=" + encoded_text + wikipedia_box.get_link();

                string ls_stdout;
                string ls_stderr;
                int ls_status;

                try {
                    Process.spawn_command_line_sync("xdg-open " + url,
                        out ls_stdout,
                        out ls_stderr,
                        out ls_status);

                } catch (SpawnError e) {
                    warning ("Error: %s\n", e.message);
                }
            });

			share_popover.set_parent(share_button);
			var share_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
			share_box.append(tweet_button);
			share_popover.set_child(share_box);

			share_button.clicked.connect(() => {
			   share_popover.popup();
			});

            var settings_button = new Gtk.Button.from_icon_name("open-menu-symbolic");
            var settings_popover = new Gtk.Popover();
            settings_popover.set_parent(settings_button);
            var settings_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);

            var run_in_background_checkbox = new Gtk.CheckButton.with_label("Keep running in background");
            var load_from_clipboard = new Gtk.CheckButton.with_label("Automatically load content from clipboard");
            var show_welcome_at_startup = new Gtk.CheckButton.with_label("Show welcome at start-up");
            settings_box.append(run_in_background_checkbox);
            settings_box.append(load_from_clipboard);
            settings_box.append(show_welcome_at_startup);

            var run_in_background = app.settings.get_boolean("run-in-background");
            var automatically_load_from_clipboard = app.settings.get_boolean("load-from-clipboard");
            var show_welcome = app.settings.get_boolean("show-welcome");

            if (run_in_background) {
                run_in_background_checkbox.set_active(true);
            } else {
                run_in_background_checkbox.set_active(false);
            }

            if (automatically_load_from_clipboard) {
                load_from_clipboard.set_active(true);
            } else {
                load_from_clipboard.set_active(false);
            }

            if (show_welcome) {
                show_welcome_at_startup.set_active(true);
            } else {
                show_welcome_at_startup.set_active(false);
            }

            run_in_background_checkbox.toggled.connect(() => {
                app.settings.set_boolean("run-in-background", run_in_background_checkbox.get_active());

            });

            load_from_clipboard.toggled.connect(() => {
                app.settings.set_boolean("load-from-clipboard", load_from_clipboard.get_active());

            });

            show_welcome_at_startup.toggled.connect(() => {
                app.settings.set_boolean("show-welcome", show_welcome_at_startup.get_active());
            });

            settings_popover.set_child(settings_box);
            settings_button.clicked.connect(() => {
               settings_popover.popup();
            });


            // Set up the main view for the application

            carousel = new Adw.Carousel();
			carousel.set_spacing(3000);
			carousel.vexpand = true;
			carousel.margin_start = 24;
			carousel.margin_end = 24;
			carousel.margin_top = 24;
			carousel.margin_bottom = 24;

            var search_term_button = new Gtk.Button.from_icon_name("system-search-symbolic");
            var search_term_revealer = new Gtk.Revealer();
            search_term_revealer.set_transition_type(Gtk.RevealerTransitionType.SLIDE_LEFT);
            var search_term_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            search_entry = new Gtk.Entry();
            search_entry.get_style_context().add_class("linked");
            search_entry.width_chars = 35;
            search_entry.placeholder_text = "Enter Search Term";
            search_term_box.append(search_entry);
            search_term_revealer.set_child(search_term_box);

            search_term_button.clicked.connect(() => {
                if(search_term_revealer.child_revealed) {
                    search_term_revealer.set_reveal_child(false);
                    search_term_button.set_icon_name("system-search-symbolic");
                } else {
                    search_term_revealer.set_reveal_child(true);
                    search_term_button.set_icon_name("go-next-symbolic");
                    search_entry.grab_focus();
                }
            });

            var copy_clipboard_button = new Gtk.Button.from_icon_name("edit-copy-symbolic");
            copy_clipboard_button.clicked.connect(on_load_clipboard);
            search_term_box.prepend(copy_clipboard_button);

            var activate_search_button = new Gtk.Button.from_icon_name("system-search-symbolic");
            search_term_box.append(activate_search_button);
            activate_search_button.get_style_context().add_class("linked");

            activate_search_button.clicked.connect(() => {
                loading_spinner.show();
                loading_spinner.start();
                search_requested(search_entry.text);

            });

            search_entry.activate.connect(() => {
                loading_spinner.show();
                loading_spinner.start();
                search_requested(search_entry.text);
            });

            search_entry.changed.connect(() => {
                app.search_text = search_entry.get_text();
            });

            app.show_search_entry_requested.connect(() => {
                if(search_term_revealer.child_revealed) {
                    search_term_revealer.set_reveal_child(false);
                    search_term_button.set_icon_name("system-search-symbolic");
                } else {
                    search_term_revealer.set_reveal_child(true);
                    search_term_button.set_icon_name("go-next-symbolic");
                    search_entry.grab_focus();
                }
            });

            loading_spinner = new Gtk.Spinner();

            header.pack_end(settings_button);
            header.pack_end(share_button);
            header.pack_end(search_term_button);
            header.pack_end(search_term_revealer);
            header.pack_end(loading_spinner);

			answers_scrolled = new Gtk.ScrolledWindow();
			answers_scrolled.set_child(answers_box);
			answers_scrolled.vexpand = true;
			answers_scrolled.hexpand = true;
			answers_scrolled.hscrollbar_policy = Gtk.PolicyType.NEVER;

			var dictionary_scrolled = new Gtk.ScrolledWindow();
			dictionary_scrolled.set_child(dictionary_box);
			dictionary_scrolled.vexpand = true;
			dictionary_scrolled.hexpand = true;
			dictionary_scrolled.hscrollbar_policy = Gtk.PolicyType.NEVER;

			var wikipedia_scrolled = new Gtk.ScrolledWindow();
			wikipedia_scrolled.set_child(wikipedia_box);
			wikipedia_scrolled.vexpand = true;
			wikipedia_scrolled.hexpand = true;
			wikipedia_scrolled.hscrollbar_policy = Gtk.PolicyType.NEVER;

            if(app.settings.get_boolean("show-welcome")) {
                carousel.append(welcome_box);
            }
            carousel.append(answers_scrolled);
            carousel.append(dictionary_scrolled);
            carousel.append(wikipedia_scrolled);

            box.append(carousel);

            var button_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            var instant_answers_button = new Gtk.ToggleButton.with_label("Instant Answers");
            var dictionary_button = new Gtk.ToggleButton.with_label("Definitions");
            var wikipedia_button = new Gtk.ToggleButton.with_label("Wikipedia");

            button_box.append(instant_answers_button);
            button_box.append(dictionary_button);
            button_box.append(wikipedia_button);
            button_box.get_style_context().add_class("linked");
            button_box.homogeneous = true;

            var button_revealer = new Gtk.Revealer();
            button_revealer.set_child(button_box);

            instant_answers_button.clicked.connect(() => {
                carousel.scroll_to(answers_scrolled, true);
            });

            dictionary_button.clicked.connect(() => {
                carousel.scroll_to(dictionary_scrolled, true);
            });

            wikipedia_button.clicked.connect(() => {
                carousel.scroll_to(wikipedia_scrolled, true);
            });

            welcome_box.next_page_selected.connect(() => {
                carousel.remove(welcome_box);
                carousel.scroll_to(answers_scrolled, true);
                if (app.settings.get_boolean("first-launch")) {
                    app.settings.set_boolean("show-welcome", false);
                    app.settings.set_boolean("first-launch", false);
                }
            });

            if (!app.settings.get_boolean("show-welcome")) {
                button_revealer.reveal_child = true;
                instant_answers_button.set_active(true);
                dictionary_button.set_active(false);
                wikipedia_button.set_active(false);
            }

            carousel.page_changed.connect((page) => {
                switch (page) {
                    case 0:
                        button_revealer.reveal_child = true;
                        instant_answers_button.set_active(true);
                        dictionary_button.set_active(false);
                        wikipedia_button.set_active(false);
                        break;

                    case 1:
                        button_revealer.reveal_child = true;
                        instant_answers_button.set_active(false);
                        dictionary_button.set_active(true);
                        wikipedia_button.set_active(false);
                        break;

                    case 2:
                        button_revealer.reveal_child = true;
                        instant_answers_button.set_active(false);
                        dictionary_button.set_active(false);
                        wikipedia_button.set_active(true);
                        break;

                    default:
                        button_revealer.reveal_child = false;
                        break;
                }
            });

            box.append(button_revealer);
            loading_spinner.hide();
            notify["visible"].connect(() => {
                if(this.visible) {
                    GLib.Timeout.add(500, () => {
                        if (app.settings.get_boolean("load-from-clipboard")) {
                            on_load_clipboard();
                        }
                        return false;
                    });
                }
            });
		}

		public void set_entries(InstantAnswer answer, DictionaryEntry dict, WikipediaEntry wiki) {
            answers_box.set_answer(answer);
            dictionary_box.set_definition(dict);
            wikipedia_box.set_wikipedia_entry(wiki);
            loading_spinner.stop();
            loading_spinner.hide();
		}

		public void set_search_text(string text) {
		    var app = application as Hypatia.Application;
		    search_entry.text = text;
		    app.search_text = text;
		}

		private void on_load_clipboard () {
            var clipboard = Gdk.Display.get_default().get_clipboard();

            clipboard.read_text_async.begin(null, (obj, res) => {
                try {
                    string search_text = clipboard.read_text_async.end(res);
                    set_search_text(search_text);

                    if (new_start) {
                        search_requested(search_text);
                        new_start = false;
                    }
                } catch (Error e) {
                    warning("Unable to load from clipboard.");
                }
            });
		}
	}
}
