using System.Net;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;
using ACSCallingNativeRegistrarLite.Utilities;
using static System.Web.HttpUtility;
using ACSCallingNativeRegistrarLite.Models;
using MongoDB.Bson;
using MongoDB.Driver;
using Newtonsoft.Json;
using MongoDB.Driver.Linq;

namespace ACSCallingNativeRegistrarLite.Functions
{
    public class ACSCallingNativeDeviceTokenRegistrar
    {
        private readonly ILogger logger;

        public ACSCallingNativeDeviceTokenRegistrar(ILoggerFactory loggerFactory)
        {
            logger = loggerFactory.CreateLogger<ACSCallingNativeDeviceTokenRegistrar>();
        }

        [Function("AddDeviceToken")]
        public async Task<HttpResponseData> AddDeviceToken([HttpTrigger(AuthorizationLevel.Anonymous, "post", Route = "add_device_token")] HttpRequestData req)
        {
            logger.LogInformation("Adding device token.");
            var requestBodyParser = new RequestBodyParser<ACSUserRegistrationInfo>();
            var registrationInfoFromBody = await requestBodyParser.Read(req);

            if (registrationInfoFromBody == null)
            {
                logger.LogError("Failed to parse body");
                return Helpers.CreateResponseData(req, HttpStatusCode.BadRequest, "Could not parse body to ACSUserRegistrationInfo");
            }

            if (registrationInfoFromBody.deviceInfos!.Count != 1)
            {
                return Helpers.CreateResponseData(req, HttpStatusCode.BadRequest, "Device tokens list is either 0 or more than 1");
            }

            if (!Enum.TryParse(registrationInfoFromBody.deviceInfos.First().platform, out Platform platform))
            {
                return Helpers.CreateResponseData(req, HttpStatusCode.BadRequest, "No platform provided");
            }

            if (platform == Platform.none)
            {
                return Helpers.CreateResponseData(req, HttpStatusCode.BadRequest, "Invalid platform provided");
            }

            using (var dbOps = new DbOps<ACSUserRegistrationInfo>(logger))
            {
                logger.LogInformation("MongoDb connection opened..");
                FilterDefinition<ACSUserRegistrationInfo> filter = new BsonDocument("_id", registrationInfoFromBody._id);
                // First fetch the entry if it exists
                var acsUserRegistrationInfos = await dbOps.FindAsync(filter)!.ConfigureAwait(false);
                if (acsUserRegistrationInfos.Count == 0)
                {
                    logger.LogInformation("Registration info not found, creating a new entry.");
                    bool result = await dbOps.CreateAsync(registrationInfoFromBody).ConfigureAwait(false);
                    if (result)
                    {
                        logger.LogInformation("Added");
                        return Helpers.CreateResponseData(req, HttpStatusCode.Created, "Successfully created the entry for the user");
                    }
                    else
                    {
                        logger.LogInformation("Failed to create new entry");
                        return Helpers.CreateResponseData(req, HttpStatusCode.InternalServerError, "Failed to add device token for the user");
                    }
                }
                else if (acsUserRegistrationInfos.Count == 1)
                {
                    var acsUserRegistrationInfo = acsUserRegistrationInfos.FirstOrDefault();
                    if (acsUserRegistrationInfo == null)
                    {
                        return Helpers.CreateResponseData(req, HttpStatusCode.InternalServerError, "Could not find the entry");
                    }

                    bool deviceUUIDExists = acsUserRegistrationInfo.deviceInfos!.Any(e => e.deviceUUID!.Equals(registrationInfoFromBody.deviceInfos.First().deviceUUID));
                    UpdateDefinition<ACSUserRegistrationInfo> update;
                    if (deviceUUIDExists)
                    {
                        filter &= Builders<ACSUserRegistrationInfo>.Filter.ElemMatch(x => x.deviceInfos, y => y.deviceUUID!.Equals(registrationInfoFromBody.deviceInfos.First().deviceUUID));
                        update = Builders<ACSUserRegistrationInfo>.Update.Set(e => e.deviceInfos.FirstMatchingElement().deviceToken, registrationInfoFromBody.deviceInfos.First().deviceToken);
                    }
                    else
                    {
                        update = Builders<ACSUserRegistrationInfo>.Update.PushEach(e => e.deviceInfos, registrationInfoFromBody.deviceInfos);
                    }

                    bool result = await dbOps.FindOneAndUpdateAsync(filter, update).ConfigureAwait(false);
                    if (result)
                    {
                        logger.LogInformation("Updated");
                        return Helpers.CreateResponseData(req, HttpStatusCode.Created, "Successfully created added the device token for the user");
                    }
                    else
                    {
                        logger.LogInformation("Failed to update entry");
                        return Helpers.CreateResponseData(req, HttpStatusCode.InternalServerError, "Failed to update device token for the user");
                    }
                }
            }

            return Helpers.CreateResponseData(req, HttpStatusCode.InternalServerError, "!! AddDeviceToken => Unexpected error !!");
        }

        // NOTE: Not required by the apps.
        [Function("GetDeviceRegistrations")]
        public async Task<HttpResponseData> GetDeviceRegistrations([HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "get_device_registrations")] HttpRequestData req)
        {
            logger.LogInformation("Getting device registrations..");
            var mri = ParseQueryString(req.Url.Query)["acsMri"];

            if (string.IsNullOrEmpty(mri))
            {
                logger.LogError("Could not find MRI in  the query");
                return Helpers.CreateResponseData(req, HttpStatusCode.BadRequest, "Could not find acsMri field in the url query");
            }

            using var dbOps = new DbOps<ACSUserRegistrationInfo>(logger);
            var userRegistrationInfo = await Helpers.GetUserRegistrationInfo(dbOps, mri);
            if (userRegistrationInfo == null)
            {
                return Helpers.CreateResponseData(req, HttpStatusCode.NotFound, "No user registration info found");
            }
            else
            {
                return Helpers.CreateResponseData(req, HttpStatusCode.OK, JsonConvert.SerializeObject(userRegistrationInfo));
            }
        }

        // To be called instead of unregisterPushNotifications
        [Function("DeleteDeviceRegistration")]
        public async Task<HttpResponseData> DeleteDeviceRegistration([HttpTrigger(AuthorizationLevel.Anonymous, "delete", Route = "delete_device_registration")] HttpRequestData req)
        {
            logger.LogInformation("Getting device uuid..");
            var deviceUUID = ParseQueryString(req.Url.Query)["deviceUUID"];
            var mri = ParseQueryString(req.Url.Query)["acsMri"];

            if (string.IsNullOrEmpty(deviceUUID) || string.IsNullOrEmpty(mri))
            {
                logger.LogError("Could not find deviceUUID or mri in  the query");
                return Helpers.CreateResponseData(req, HttpStatusCode.BadRequest, "Could not find deviceUUID or mri field in the url query");
            }

            using (var dbOps = new DbOps<ACSUserRegistrationInfo>(logger))
            {
                FilterDefinition<ACSUserRegistrationInfo> filter = new BsonDocument("_id", mri);
                var acsUserRegistrationInfos = await dbOps.FindAsync(filter)!.ConfigureAwait(false);
                if (acsUserRegistrationInfos.Count == 0)
                {
                    return Helpers.CreateResponseData(req, HttpStatusCode.BadRequest, "Could not find entry for the mri");
                }
                else if (acsUserRegistrationInfos.Count == 1)
                {
                    var acsRegistrationInfo = acsUserRegistrationInfos.First();
                    if (acsRegistrationInfo == null)
                    {
                        return Helpers.CreateResponseData(req, HttpStatusCode.InternalServerError, "Unexpected to find empty entry");
                    }

                    if (acsRegistrationInfo.deviceInfos == null)
                    {
                        return Helpers.CreateResponseData(req, HttpStatusCode.BadRequest, "No devices or tokens registered");
                    }

                    var allDeviceUUIDs = acsRegistrationInfo.deviceInfos.Select(kvp => kvp.deviceUUID).ToList();
                    if (allDeviceUUIDs.Contains(deviceUUID))
                    {
                        bool result = false;
                        if (acsRegistrationInfo.deviceInfos.Count == 1)
                        {
                            // there is only one entry delete the entire document
                            result = await dbOps.DeleteOneAsync(filter);
                        }
                        else
                        {
                            var update = Builders<ACSUserRegistrationInfo>.Update.PullFilter(e => e.deviceInfos, z => z.deviceUUID!.Equals(deviceUUID));
                            result = await dbOps.FindOneAndUpdateAsync(filter, update);
                        }

                        if (result)
                        {
                            return Helpers.CreateResponseData(req, HttpStatusCode.OK, "Removed the deviceUUID");
                        }
                        else
                        {
                            return Helpers.CreateResponseData(req, HttpStatusCode.InternalServerError, "Failed to remove the entry");
                        }
                    }
                }
                else
                {
                    return Helpers.CreateResponseData(req, HttpStatusCode.InternalServerError, "Unexpected found more than 1 entry.");
                }
            }

            return Helpers.CreateResponseData(req, HttpStatusCode.InternalServerError, "!! DeleteDeviceRegistration => Unexpected error!!");
        }
    }
}
