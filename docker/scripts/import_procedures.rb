# frozen_string_literal: true
#
# Import démarches from a JSON file into the instance this runs in (GPP or DS).
#
# Usage (docker/scripts/import_procedures.sh wraps it for the test stand):
#   bin/rails runner import_procedures.rb [path/to/procedures.json]
#
# JSON format - see sample_procedures.json for a full example.
# Required keys per démarche:
#   libelle, description, administrateur_email
# Optional keys:
#   organisation (default: ""), cadre_juridique (default: "À compléter"),
#   for_individual (default: true), no_gender (default: false),
#   duree_conservation_dossiers_dans_ds (default: 12),
#   publish (default: false), path (end of the published link, default: generated),
#   lien_site_web (page where the link is shared, default: "https://example.org"),
#   champs (list of fields)
# Supported type_champ values:
#   text, textarea, integer_number, decimal_number, email, phone, address,
#   date, datetime, checkbox, siret, civilite,
#   drop_down_list (requires "options" array),
#   multiple_drop_down_list (requires "options" array),
#   piece_justificative, header_section, explication
#
# A démarche cannot be published without a service: publishing attaches the
# administrateur's "Service de test", created on first use.

require "json"

TEST_SERVICE = {
  organisme: "GIP CAD (test)",
  type_organisme: "autre",
  siret: "13002526500013",
  email: "contact@example.org",
  horaires: "Du lundi au vendredi de 9h à 17h",
  adresse: "1 rue de Test, 75000 Paris"
}.freeze

def test_service_for(admin)
  Service.create_with(TEST_SERVICE).find_or_create_by!(administrateur: admin, nom: "Service de test")
end

json_path = ARGV.first || File.join(__dir__, "sample_procedures.json")

unless File.exist?(json_path)
  warn "ERROR: file not found: #{json_path}"
  exit 1
end

definitions = JSON.parse(File.read(json_path))
created = 0
skipped = 0
failed  = 0

definitions.each do |defn|
  admin_email = defn.fetch("administrateur_email")
  user = User.find_by(email: admin_email)

  unless user
    warn "ERROR: user not found: #{admin_email}"
    failed += 1
    next
  end

  admin = user.administrateur
  unless admin
    warn "ERROR: #{admin_email} is not an administrateur"
    failed += 1
    next
  end

  libelle = defn.fetch("libelle")

  if admin.procedures.exists?(libelle:)
    puts "SKIP:    '#{libelle}' (already exists for #{admin_email})"
    skipped += 1
    next
  end

  ActiveRecord::Base.transaction do
    duree = defn.fetch("duree_conservation_dossiers_dans_ds", 12).to_i
    procedure = Procedure.new(
      libelle:,
      description:                           defn.fetch("description"),
      organisation:                          defn.fetch("organisation", ""),
      cadre_juridique:                       defn.fetch("cadre_juridique", "À compléter"),
      for_individual:                        defn.fetch("for_individual", true),
      duree_conservation_dossiers_dans_ds:   duree,
      max_duree_conservation_dossiers_dans_ds: [duree, 100].min,
      no_gender:                             defn.fetch("no_gender", false),
      administrateurs:                       [admin]
    )
    procedure.draft_revision = procedure.revisions.build
    procedure.save!
    procedure.create_generic_labels
    admin.instructeur.assign_to_procedure(procedure)

    Array(defn["champs"]).each do |champ|
      params = {
        type_champ:  champ.fetch("type_champ"),
        libelle:     champ.fetch("libelle"),
        mandatory:   champ.fetch("mandatory", false),
        description: champ.fetch("description", "")
      }
      params[:drop_down_options] = champ["options"] if champ["options"]
      procedure.draft_revision.add_type_de_champ(params)
    end

    if defn.fetch("publish", false)
      procedure.update!(service: test_service_for(admin), lien_site_web: defn.fetch("lien_site_web", "https://example.org"))
      procedure.publish_or_reopen!(admin, defn.fetch("path", procedure.path))
      puts "CREATED: '#{libelle}' (n° #{procedure.id}), published at /commencer/#{procedure.path}"
    else
      puts "CREATED: '#{libelle}' (n° #{procedure.id}), brouillon"
    end

    created += 1
  end
rescue => e
  warn "ERROR:   '#{defn['libelle']}' - #{e.message}"
  failed += 1
end

puts "\nDone: #{created} created, #{skipped} skipped, #{failed} failed."
