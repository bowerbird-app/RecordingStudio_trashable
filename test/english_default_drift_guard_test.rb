# frozen_string_literal: true

require "test_helper"
require "yaml"

# Ensures production call sites for gem keys do not hand-copy English from
# en.yml as `default:`. English fallback comes from RecordingStudio.t /
# loaded :en / register_shipped_english instead.
#
# Scanner covers single-quoted, double-quoted, multi-line, paren-less,
# I18n.translate, constant, and Array defaults.
class EnglishDefaultDriftGuardTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  SCAN_GLOBS = %w[
    app/**/*.{rb,erb}
    lib/**/*.rb
  ].freeze
  SKIP_PATH_FRAGMENTS = %w[
    /generators/
  ].freeze

  TRANSLATION_CALL = /
    (?:
      RecordingStudioTrashable::Copy\.t |
      RecordingStudio\.t |
      Copy\.t |
      trashable_t |
      I18n\.translate |
      I18n\.t\b
    )
  /x

  def test_production_translation_calls_do_not_hand_copy_en_yml_english_defaults
    en_values = en_yml_leaf_values

    offenders = []
    scan_files.each do |path|
      source = File.read(path)
      source = strip_ruby_comments(source) if path.end_with?(".rb")

      each_translation_call(source) do |call_source|
        each_default_argument(call_source) do |default_src|
          next if allowed_dynamic_default?(default_src)

          values = default_values(default_src, {})
          values.each do |value|
            next unless en_values.include?(value)

            offenders << "#{relative(path)}: default: #{default_src} => #{value.inspect}"
          end
        end
      end
    end

    assert_empty offenders, <<~MSG
      Hand-copied English default:s drift from en.yml. Remove them and rely on
      RecordingStudio.t / Copy.t fallback instead.
      #{offenders.join("\n")}
    MSG
  end

  def test_scanner_catches_single_quoted_multiline_paren_less_translate_constant_and_array_defaults
    sample = <<~RUBY
      Copy.t("trash.title", default: 'Trash')
      Copy.t(
        "trash.settings",
        default: "Settings"
      )
      trashable_t "home.title", default: "Overview"
      I18n.translate("recording_studio.trashable.flashes.settings_updated", default: "Trash settings updated.")
      Copy.t("errors.purge_after_days_invalid", default: PURGE_INVALID)
      Copy.t("trash.title", default: ["Trash", "Other"])
    RUBY

    en_values = en_yml_leaf_values
    constant_values = { "PURGE_INVALID" => "must be a positive whole number" }
    hits = []

    each_translation_call(sample) do |call_source|
      each_default_argument(call_source) do |default_src|
        hits.concat(default_values(default_src, constant_values).select { |value| en_values.include?(value) })
      end
    end

    assert_includes hits, "Trash"
    assert_includes hits, "Settings"
    assert_includes hits, "Overview"
    assert_includes hits, "Trash settings updated."
    assert_includes hits, "must be a positive whole number"
    assert_equal 2, hits.count("Trash"), "array + single-quoted Trash"
  end

  private

  def scan_files
    SCAN_GLOBS.flat_map { |glob| Dir[File.join(ROOT, glob)] }
              .uniq
              .reject { |path| SKIP_PATH_FRAGMENTS.any? { |frag| path.include?(frag) } }
  end

  def relative(path)
    path.delete_prefix("#{ROOT}/")
  end

  def en_yml_leaf_values
    tree = YAML.safe_load_file(File.join(ROOT, "config/locales/en.yml"), aliases: true)
               .fetch("en").fetch("recording_studio").fetch("trashable")
    flatten_values(tree).to_set
  end

  def flatten_values(node)
    case node
    when Hash then node.values.flat_map { |value| flatten_values(value) }
    when Array then node.flat_map { |value| flatten_values(value) }
    else [node]
    end
  end

  def strip_ruby_comments(source)
    source.gsub(/^\s*#.*$/, "")
  end

  def each_translation_call(source)
    index = 0
    while (match = source.match(TRANSLATION_CALL, index))
      start = match.end(0)
      call_body = extract_call_body(source, start, match[0])
      yield "#{match[0]}#{call_body}"
      index = start + 1
    end
  end

  def extract_call_body(source, start, method_name)
    return paren_body(source, start) if source[start] == "("
    if method_name.strip.match?(/\A(?:trashable_t|I18n\.(?:t|translate))\z/)
      return " #{slice_until_newline(source, start)}"
    end

    ""
  end

  def paren_body(source, open_index)
    depth = 0
    i = open_index
    while i < source.length
      case source[i]
      when "(" then depth += 1
      when ")"
        depth -= 1
        return source[open_index..i] if depth.zero?
      when "\"", "'"
        i = skip_string(source, i)
      end
      i += 1
    end
    source[open_index..]
  end

  def skip_string(source, quote_index)
    quote = source[quote_index]
    i = quote_index + 1
    while i < source.length
      return i if source[i] == quote && source[i - 1] != "\\"

      i += 1
    end
    i
  end

  def slice_until_newline(source, start)
    line_end = source.index("\n", start) || source.length
    source[start...line_end]
  end

  def each_default_argument(call_source)
    index = 0
    while (match = call_source.match(/\bdefault:\s*/, index))
      start = match.end(0)
      default_src = extract_ruby_expression(call_source, start)
      yield default_src.strip
      index = start + [default_src.length, 1].max
    end
  end

  # rubocop:disable Metrics/CyclomaticComplexity -- expression scanner
  def extract_ruby_expression(source, start)
    return source[start..] if start >= source.length

    case source[start]
    when "\"" then string_literal(source, start, "\"")
    when "'" then string_literal(source, start, "'")
    when "[" then balanced(source, start, "[", "]")
    when "{" then balanced(source, start, "{", "}")
    else
      rest = source[start..]
      rest[/\A[A-Za-z_][A-Za-z0-9_:]*/] || rest[/\A[^,\n)]+/] || ""
    end
  end
  # rubocop:enable Metrics/CyclomaticComplexity

  def string_literal(source, start, quote)
    i = start + 1
    while i < source.length
      return source[start..i] if source[i] == quote && source[i - 1] != "\\"

      i += 1
    end
    source[start..]
  end

  def balanced(source, start, open, close)
    depth = 0
    i = start
    while i < source.length
      case source[i]
      when open then depth += 1
      when close
        depth -= 1
        return source[start..i] if depth.zero?
      when "\"", "'"
        i = skip_string(source, i)
      end
      i += 1
    end
    source[start..]
  end

  def allowed_dynamic_default?(default_src)
    # action_name falls back to the raw action token for unknown actions.
    default_src.strip == "name"
  end

  # rubocop:disable Metrics/CyclomaticComplexity -- default: value shapes
  def default_values(default_src, constant_values)
    stripped = default_src.strip
    if (match = stripped.match(/\A(["'])(.*)\1\z/m))
      return [match[2].gsub('\\"', '"').gsub("\\'", "'")]
    end

    if stripped.start_with?("[") && stripped.end_with?("]")
      inner = stripped[1...-1]
      return inner.scan(/(["'])(.*?)\1/m).map { |(_, value)| value }
    end

    if stripped.start_with?("{") && stripped.end_with?("}")
      return stripped.scan(/(["'])(.*?)\1/m).map { |(_, value)| value }
    end

    Array(constant_values[stripped])
  end
  # rubocop:enable Metrics/CyclomaticComplexity
end
