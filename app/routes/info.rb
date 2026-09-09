require 'sinatra'

class Web < Sinatra::Base

  # Author biography: /author/<name>/info
  #
  # Serves the bio from the `authors` collection (loaded by the poetrydb_data
  # pipeline). NOTE: this route must be registered BEFORE the generic
  # /:keys/:search/... routes in all.rb (see routes/init.rb require order),
  # or the catch-alls would swallow it.
  get '/author/:author/info' do
    content_type :json

    author = params[:author]
    doc = settings.mongo_db.collection('authors').find({ 'name' => author }).first

    if doc.nil?
      # distinguish "unknown author" from "known author, no bio yet"
      known = settings.poetry_coll.find({ 'author' => author }).limit(1).first
      if known.nil?
        return json_status('404', "No author found for '#{author}'.")
      else
        return json_status('404', "No biography available yet for '#{author}'.")
      end
    end

    doc.delete('_id')
    # defence in depth: editorial layers are stripped at publish time, but never
    # serve an underscore-prefixed key even if one slips through
    doc.reject! { |k, _| k.to_s.start_with?('_') }
    # poem_count is always the live corpus count, never a stored snapshot
    doc['poem_count'] = settings.poetry_coll.count_documents({ 'author' => author })

    JSON.pretty_generate(doc)
  end
end
