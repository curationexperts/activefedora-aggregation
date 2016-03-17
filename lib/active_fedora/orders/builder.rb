module ActiveFedora::Orders
  class Builder < ActiveFedora::Associations::Builder::CollectionAssociation
    include ActiveFedora::AutosaveAssociation::AssociationBuilderExtension
    self.macro = :orders
    self.valid_options += [:through, :ordered_reflection]

    def self.define_readers(mixin, name)
      super
      mixin.redefine_method(target_accessor(name)) do
        association(name).target_reader
      end
      mixin.redefine_method("#{target_accessor(name)}=") do |nodes|
        association(name).target_writer(nodes)
      end
    end

    def initialize(model, name, options)
      @original_name = name
      @model = model
      name = :"ordered_#{name.to_s.singularize}_proxies"
      options = {ordered_reflection: ordered_reflection}.merge(options)
      super
    end

    module FixFirstLast
      def save(*args)
        super.tap do |result|
          if result
            apply_first_and_last
          end
        end
      end
      def save!(*args)
        super.tap do |result|
          if result
            apply_first_and_last
          end
        end
      end
    end

    def build
      super.tap do |result|
        model.property :head, predicate: ::RDF::Vocab::IANA['first']
        model.property :tail, predicate: ::RDF::Vocab::IANA.last
        model.send(:define_method, :apply_first_and_last) do
          source = send(result.options[:through])
          return if head.map(&:rdf_subject) == source.head_id && tail.map(&:rdf_subject) == source.tail_id
          self.head = source.head_id
          self.tail = source.tail_id
          save! if changed?
        end
        model.include ActiveFedora::Orders::Builder::FixFirstLast
      end
    end

    private

    def self.target_accessor(name)
      name.to_s.gsub("_proxies","").pluralize
    end

    def ordered_reflection
      model.reflect_on_association(@original_name)
    end
  end
end

