module RubyFS
  class Lexer
    ContentLengthPattern  = /Content-length:\s*(\d+)/i
    MaxLineLength         = 16 * 1024
    MaxBinaryLength       = 32 * 1024 * 1024

    def initialize(callback)
      @callback = callback

      @data_mode  = :lines
      @delimiter  = "\n"
      @linebuffer = []

      init_for_request
    end

    def receive_data(data)
      return unless data && data.length > 0

      case @data_mode
      when :lines
        receive_line_data data
      when :text
        receive_text_data data
      end
    end
    alias :<< :receive_data

    private

    def receive_line_data(data)
      if ix = data.index(@delimiter)
        @linebuffer << data[0...ix]
        ln = @linebuffer.join
        @linebuffer.clear
        ln.chomp! if @delimiter == "\n"
        receive_line ln
        receive_data data[(ix + @delimiter.length)..-1]
      else
        @linebuffer << data
      end
    end

    def receive_text_data(data)
      if @textsize
        needed = @textsize - @textpos
        will_take = data.length > needed ? needed : data.length

        @textbuffer << data[0...will_take]
        tail = data[will_take..-1]

        @textpos += will_take
        if @textpos >= @textsize
          set_line_mode
          receive_binary_data @textbuffer.join
        end

        receive_data tail
      else
        receive_binary_data data
      end
    end

    def receive_line(line)
      case @hc_mode
      when :discard_blanks
        unless line == ""
          @hc_mode = :headers
          receive_line line
        end
      when :headers
        if line == ""
          raise "unrecognized state" unless @headers.length > 0
          # @hc_content_length will be nil, not 0, if there was no content-length header.
          if @content_length.to_i > 0
            set_binary_mode @content_length
          else
            dispatch_request
          end
        else
          @headers << line
          if ContentLengthPattern =~ line
            # There are some attacks that rely on sending multiple content-length
            # headers. This is a crude protection, but needs to become tunable.
            raise "extraneous content-length header" if @content_length
            @content_length = $1.to_i
          end
        end
      else
        raise "internal error, unsupported mode"
      end
    end

    def receive_binary_data(text)
      @content = text
      dispatch_request
    end

    def dispatch_request
      @callback.call headers_2_hash(@headers), @content if @callback.respond_to?(:call)
      init_for_request
    end

    def init_for_request
      @hc_mode = :discard_blanks
      @headers = []
      @content_length = nil
      @content = ""
    end

    # Called internally but also exposed to user code, for the case in which
    # processing of binary data creates a need to transition back to line mode.
    # We support an optional parameter to "throw back" some data, which might
    # be an unprocessed chunk of the transmitted binary data, or something else
    # entirely.
    def set_line_mode(data = "")
      @data_mode = :lines
      (@linebuffer ||= []).clear
      receive_data data.to_s
    end

    def set_text_mode(size = nil)
      if size == 0
        set_line_mode
      else
        @data_mode = :text
        (@textbuffer ||= []).clear
        @textsize = size # which can be nil, signifying no limit
        @textpos = 0
      end
    end

    def set_binary_mode(size = nil)
      set_text_mode size
    end

    def headers_2_hash(headers)
      {}.tap do |hash|
        headers.each do |h|
          if /\A([^\s:]+)\s*:\s*/ =~ h
            tail = $'.dup
            hash[$1.downcase.gsub(/-/, "_").intern] = tail
          end
        end
      end
    end
  end
end
