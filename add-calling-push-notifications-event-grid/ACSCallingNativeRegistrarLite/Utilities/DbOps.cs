using Microsoft.Extensions.Logging;
using MongoDB.Bson;
using MongoDB.Driver;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Authentication;
using System.Text;
using System.Threading.Tasks;

namespace ACSCallingNativeRegistrarLite.Utilities
{
    public delegate void InitEmptyLists();

    public class DbOps<T> : IDisposable
    {
        private bool disposed = false;
        private static string CollectionName = "DeviceTokensColl";
        private static readonly string? MongodbConnectionString = Environment.GetEnvironmentVariable("MongoDbConnectionString");
        private static readonly string? DbName = Environment.GetEnvironmentVariable("DbName");

        private MongoClient Client;
        private IMongoDatabase Database;
        private IMongoCollection<T> Collection;
        private ILogger logger;

        // Default constructor. 
        public DbOps(ILogger logger)
        {
            this.logger = logger;
            Client = CreateNewMongoClient();
            Database = Client.GetDatabase(DbName);
            Collection = Database.GetCollection<T>(CollectionName);
        }

        // For updating specific keys in a document
        // Filter finds the document, and adds to the list, will not upsert
        public async Task<bool> FindOneAndUpdateAsync(FilterDefinition<T> filter, UpdateDefinition<T> update, FindOneAndUpdateOptions<T>? updateOptions=null)
        {
            try
            {
                var updatedDoc = await Collection.FindOneAndUpdateAsync(filter: filter, update: update, options: updateOptions).ConfigureAwait(false);
                if (updatedDoc == null)
                {
                    logger.LogWarning("Document does not exist");
                    return false;
                }
                else
                {
                    logger.LogInformation("Document updated");
                    return true;
                }
            }
            catch (Exception ex)
            {
                logger.LogCritical("Failed to update: " + ex.Message);
            }

            return false;
        }

        public async Task<bool> DeleteOneAsync(FilterDefinition<T> filter)
        {
            try
            {
                DeleteResult? result = await Collection.DeleteOneAsync(filter).ConfigureAwait(false);
                return true;
            }
            catch (Exception ex)
            {
                logger.LogCritical("Failed to DeleteOne: " + ex.Message);
            }

            return false;
        }

        public async Task<List<T>> FindAsync(FilterDefinition<T> filter)
        {
            try
            {
                return await Collection.Find(filter).ToListAsync().ConfigureAwait(false);
            }
            catch (Exception ex)
            {
                logger.LogCritical("Failed to Get: " + ex.Message);
                return new List<T>();
            }
        }

        // Gets all Task items from the MongoDB server
        public async Task<List<T>> GetAllAsync()
        {
            try
            {
                return await Collection.Find(new BsonDocument()).ToListAsync().ConfigureAwait(false);
            }
            catch (Exception ex)
            {
                logger.LogCritical("Failed to GetAll: " + ex.Message);
                return new List<T>();
            }
        }

        // Inserts a new document
        public async Task<bool> CreateAsync(T document)
        {
            try
            {
                await Collection.InsertOneAsync(document).ConfigureAwait(false);
                return true;
            }
            catch (Exception ex)
            {
                logger.LogCritical("Failed to Create: " + ex.Message);
            }

            return false;
        }

        private MongoClient CreateNewMongoClient()
        {
            MongoClientSettings? settings = MongoClientSettings.FromUrl(
                new MongoUrl(MongodbConnectionString)
            );
            settings.SslSettings = 
            new SslSettings() { EnabledSslProtocols = SslProtocols.Tls12 };
            return new MongoClient(settings);
        }

        # region IDisposable

        public void Dispose()
        {
            this.Dispose(true);
            GC.SuppressFinalize(this);
        }

        protected virtual void Dispose(bool disposing)
        {
            if (!this.disposed)
            {
                if (disposing)
                {
                }
            }
            this.disposed = true;
        }

        # endregion
    }
}
