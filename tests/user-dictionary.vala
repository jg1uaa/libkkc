class UserDictionaryTests : Kkc.TestCase {
    Kkc.Context context;

    public UserDictionaryTests () {
        base ("UserDictionary");

        try {
            Kkc.LanguageModel model = Kkc.LanguageModel.load ("sorted3");
            context = new Kkc.Context (model);
        } catch (Kkc.LanguageModelError e) {
            stderr.printf ("%s\n", e.message);
        }

        add_test ("conversion", this.test_conversion);
        add_test ("register", this.test_register);
    }

    struct ConversionData {
        string keys;
        string input;
        string segments;
        int segments_size;
        int segments_cursor_pos;
        string output;
    }

    void do_conversions (ConversionData[] conversions) {
        foreach (var conversion in conversions) {
            context.process_key_events (conversion.keys);
            var output = context.poll_output ();
            assert (output == conversion.output);
            assert (context.input == conversion.input);
            assert (context.segments.get_output () == conversion.segments);
            assert (context.segments.size == conversion.segments_size);
            assert (context.segments.cursor_pos == conversion.segments_cursor_pos);
            context.reset ();
            context.clear_output ();
        }
    }

    static const ConversionData CONVERSION_DATA[] = {
        { "SPC",
          "わたしのなまえはなかのです",
          "私の名前は中のです",
          9,
          0,
          "" },
        { "SPC Right Right Right C-Left RET",
          "",
          "",
          0,
          -1,
          "私の名まえは中のです" },
        { "SPC",
          "わたしのなまえはなかのです",
          "私の名まえは中のです",
          10,
          0,
          "" },
        { "SPC SPC RET",
          "",
          "",
          0,
          -1,
          "渡しの名まえは中のです" },
        { "SPC",
          "わたしのなまえはなかのです",
          "渡しの名まえは中のです",
          10,
          0,
          "" },
        { "SPC Right SPC Right SPC",
          "わたしのなまえはなかのです",
          "渡し埜那まえは中のです",
          10,
          2,
          "" }
    };

    public void test_conversion () {
        const string PREFIX_KEYS =
            "w a t a s h i n o n a m a e h a n a k a n o d e s u ";

        ConversionData[] conversions =
            new ConversionData[CONVERSION_DATA.length];

        for (var i = 0; i < CONVERSION_DATA.length; i++) {
            conversions[i] = CONVERSION_DATA[i];
            conversions[i].keys = PREFIX_KEYS + CONVERSION_DATA[i].keys;
        }

        do_conversions (conversions);

        context.dictionaries.save ();

        try {
            new Kkc.UserDictionary ("test-user-dictionary");
        } catch (Error e) {
            assert_not_reached ();
        }
    }

    static const ConversionData REGISTER_DATA[] = {
        { "a i SPC",
          "わたしのなまえはなかのです",
          "私の名前は中のです",
          9,
          0,
          "" },
        { "SPC Right Right Right C-Left RET",
          "",
          "",
          0,
          -1,
          "私の名まえは中のです" },
        { "SPC",
          "わたしのなまえはなかのです",
          "私の名まえは中のです",
          10,
          0,
          "" },
        { "SPC SPC RET",
          "",
          "",
          0,
          -1,
          "渡しの名まえは中のです" },
        { "SPC",
          "わたしのなまえはなかのです",
          "渡しの名まえは中のです",
          10,
          0,
          "" }
    };

    public void test_register () {
        var handler_id = context.request_selection_text.connect (() => {
                context.set_selection_text ("abc");
            });
        context.process_key_events ("A-r a i SPC RET");
        context.reset ();
        context.clear_output ();
        context.process_key_events ("a i SPC");
        assert (context.segments.size == 1);
        assert (context.segments.get_output () == "abc");
        context.reset ();
        context.clear_output ();

        context.dictionaries.save ();

        context.disconnect (handler_id);
        context.request_selection_text.connect (() => {
                context.set_selection_text (null);
            });
        context.process_key_events ("A-r a i SPC");
        context.reset ();
        context.clear_output ();
        
        try {
            new Kkc.UserDictionary ("test-user-dictionary");
        } catch (Error e) {
            assert_not_reached ();
        }

        context.process_key_events ("a TAB");
        context.reset ();
        context.clear_output ();

        context.process_key_events ("a i SPC C-BackSpace");
        context.reset ();
        context.clear_output ();

        context.process_key_events ("a i SPC");
        assert (context.segments.size == 1);
        assert (context.segments.get_output () != "abc");
        context.reset ();
        context.clear_output ();
    }

    public override void set_up () {
        if (FileUtils.test ("test-user-dictionary", FileTest.EXISTS))
            Kkc.TestUtils.remove_dir ("test-user-dictionary");

        Kkc.UserDictionary user_dictionary;
        try {
            var srcdir = Environment.get_variable ("srcdir");
            assert (srcdir != null);
            user_dictionary = new Kkc.UserDictionary (
                Path.build_filename (srcdir, "test-user-dictionary"));
            context.dictionaries.add (user_dictionary);
        } catch (Error e) {
            assert_not_reached ();
        }

        try {
            var srcdir = Environment.get_variable ("srcdir");
            assert (srcdir != null);
            var dictionary = new Kkc.SystemSegmentDictionary (
                Path.build_filename (srcdir, "file-dict.dat"));
            context.dictionaries.add (dictionary);
        } catch (Error e) {
            stderr.printf ("%s\n", e.message);
        }
    }
}

int main (string[] args)
{
  Test.init (ref args);
  Kkc.init ();

  TestSuite root = TestSuite.get_root ();
  root.add_suite (new UserDictionaryTests ().get_suite ());

  Test.run ();

  return 0;
}