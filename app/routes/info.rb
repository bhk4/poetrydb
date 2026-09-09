require 'sinatra'

class Web < Sinatra::Base

  # Author biographies: /author/<author>/info
  #
  # Matching follows the API's idiom for author searches: case-insensitive
  # substring by default (/author/Shelley/info), exact string with the :abs
  # modifier (/author/Percy Bysshe Shelley:abs/info). Returns a JSON array of
  # matching biographies, as other search endpoints return arrays of poems.
  #
  # Bios are served from the `authors` collection (loaded by the poetrydb_data
  # pipeline). NOTE: this route must be registered BEFORE the generic
  # /:keys/:search/... routes in all.rb (see routes/init.rb require order),
  # or the catch-alls would swallow it.
  get '/author/:author/info' do
    content_type :json

    search = search_regex(params[:author])
    authors_coll = settings.mongo_db.collection('authors')
    docs = authors_coll.find({ 'name' => search }).sort({ 'name' => 1 }).to_a

    if docs.empty?
      # distinguish "unknown author" from "known author, no biography yet"
      known = settings.poetry_coll.find({ 'author' => search }).limit(1).first
      if known.nil?
        return json_status('404', "No author found matching '#{params[:author]}'.")
      else
        return json_status('404', "No biography available yet for '#{params[:author]}'.")
      end
    end

    docs.each do |doc|
      doc.delete('_id')
      # defence in depth: editorial layers are stripped at publish time, but
      # never serve an underscore-prefixed key even if one slips through
      doc.reject! { |k, _| k.to_s.start_with?('_') }
      # poem_count is always the live corpus count, never a stored snapshot
      doc['poem_count'] = settings.poetry_coll.count_documents({ 'author' => doc['name'] })
    end

    JSON.pretty_generate(docs)
  end
end
