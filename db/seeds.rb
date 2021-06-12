tag_and_items = {
    'Sports' => %w(soccer basketball tennis baseball golf running volleyball badminton)
}

tag_and_items.each do |tag, word_list|
  word_tag = WordTag.find_or_create_by(name: tag)
  word_list.each do |word|
    WordItem.find_or_create_by(name: word, word_tag_id: word_tag.id)
  end
end
