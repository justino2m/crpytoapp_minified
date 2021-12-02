### Setup
```
rake db:create
rake db:schema:load
```

Make sure these specs are passing:
```
rspec spec/integration/api/csv_imports_spec.rb
rspec spec/importers
```

### Adding an api importer

`rails g importer kraken api_key api_secret`

Look at the generated files and also files of other importers to get an idea of what needs to be done.

### Adding a CSV mapper
Add the csv file to the fixtures/files folder and add a spec for it in `spec/integration/api/csv_imports_spec.rb`

Create a mapper class inside the `app/csv_mappers/` folder. Look at the other mappers to figure things out. For details about all the mapped fields, refer to the Engineering wiki.

### To improve performance, look at the following specs:

```rspec spec/importers/binance_importer_spec.rb:30```

It imports 22k transactions using VCR then runs the InvestmentsUpdater on the user. If you are focusing on the InvestmentsUpdater, I would suggest importing the transactions into development environment (by configuring and using vcr in dev mode). Otherwise you will have to wait a long time to import transactions before the updater can run.
