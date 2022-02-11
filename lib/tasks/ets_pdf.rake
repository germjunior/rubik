# frozen_string_literal: true
namespace :ets_pdf do
  task etl: :environment do
    EtsPdf::Etl.call(*ENV["PDF_FOLDER"])
  end
end
