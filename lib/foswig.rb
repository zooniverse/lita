class Foswig
    class TrieNode
        attr_reader :children

        def initialize
            @children = {}
        end
    end

    class Node
        attr_reader :character, :neighbours

        def initialize(character)
            @character = character
            @neighbours = []
        end
    end

    attr_reader :order, :duplicates, :start, :map

    def initialize(order)
        @order = order
        @duplicates = TrieNode.new
        @start = Node.new('')
        @map = {}
    end

    def add_words(words)
        for word in words
            add_word(word)
        end
    end

    def add_word(word)
        add_to_duplicates_trie(word.downcase)

        previous = @start
        key = ""

        word.chars.each_with_index do |ch, idx|
            key += ch

            if key.size > @order
                key = key[1..-1]
            end

            @map[key] ||= Node.new(ch)
            previous.neighbours << @map[key]
            previous = @map[key]
        end

        previous.neighbours.push(nil)
    end

    def add_to_duplicates_trie(word)
        if word.size > 1
            add_to_duplicates_trie(word[1..-1])
        end

        current_node = @duplicates

        word.chars.each do |ch|
            current_node.children[ch] ||= TrieNode.new
            current_node = current_node.children[ch]
        end
    end

    def generate_word(min = 0, max = -1, dupes = true, max_attempts = 25)
        repeat = false
        attempts = 0
        word = ""

        begin 
            repeat = false
            attempts += 1

            if attempts > max_attempts
                raise "Unable to generate"
            end

            current_node = @start.neighbours.sample
            word = ""

            while current_node && (max < 0 || word.size <= max)
                word += current_node.character
                current_node = current_node.neighbours.sample
            end

            if (max >= 0 && word.size > max) || word.size < min
                repeat = true
            end
        end while repeat || (!dupes && is_duplicate(word, @duplicates))

        word
    end

    def is_duplicate(word, duplicates)
        word = word.downcase
        current_node = duplicates

        word.chars.each_with_index do |ch, idx|
            child_node = current_node.children[ch]
            
            if !child_node
                return false
            end
            current_node = child_node
        end

        true
    end
end
