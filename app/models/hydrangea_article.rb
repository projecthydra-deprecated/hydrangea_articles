require "hydra"

class HydrangeaArticle < ActiveFedora::Base
  
  include Hydra::ModelMethods
  
  has_relationship "parts", :is_part_of, :inbound => true
  
  # Uses the Hydra Rights Metadata Schema for tracking access permissions & copyright
  has_metadata :name => "rightsMetadata", :type => Hydra::RightsMetadata 
  
  # Uses the Hydra MODS Article profile for tracking most of the descriptive metadata
  has_metadata :name => "descMetadata", :type => Hydra::ModsArticle 

  # A place to put extra metadata values
  has_metadata :name => "properties", :type => ActiveFedora::MetadataDatastream do |m|
    m.field 'collection', :string
    m.field 'depositor', :string
    m.field 'license_uva', :string    
    m.field 'license_cc_by', :string        
    m.field 'license_cc_by_nc', :string            
    m.field 'license_cc_by_sa', :string            
    m.field 'released', :string
    m.field 'release_to', :string
  end
  
  def to_solr(solr_doc=Solr::Document.new,opts={})
    super(solr_doc, opts)
    if datastreams["properties"].released_values == ["true"] 
      solr_doc = apply_release(solr_doc)
    end
    solr_doc
  end
  
  # Placeholder method that applies access rights if the object has been released and satisfies the requirements for release
  # The value of the "release_to" entry in the properties datastream is used to decide who should be granted access to the article.
  # If no release_to value has been set, defaults to "public"
  #
  # Requirements for release
  # * title is set
  # * an author is set
  # * at least one file has been uploaded
  #
  def apply_release(solr_doc)
    if ready_to_release?
      release_to = datastreams["properties"].release_to_values.first
      if release_to.nil?
        release_to = "public"
      end
      solr_doc << Solr::Field.new(:read_access_group_t => release_to)
    end
    solr_doc
  end
  
  def ready_to_release?
    if test_release_readiness == true
      return true
    else
      return false
    end
  end
  
  # Tests whether the object is ready to release
  # @return true if ready, otherwise a Hash where response[:failures] is an array of failure messages
  def test_release_readiness
    author_entries = datastreams["descMetadata"].find_by_terms_and_value('//oxns:name[@type="personal" and contains(oxns:role, "Author") and string-length(oxns:namePart[@type="family"]) > 0 ]')    
    title_values = datastreams["descMetadata"].term_values(:title_info, :main_title)
    
    response = {:failures=>[]}

    if title_values.first.empty?
      response[:failures] << "You must provide a title."
    end  
    if author_entries.empty?
      response[:failures] << "You must provide an author (first name and last name)."
    end  
    if parts(:response_format=>:id_array).empty?
      response[:failures] << "You must attach at least one file."
    end
    
    if response[:failures].empty? 
      return true
    else
      return response
    end
  end
end
