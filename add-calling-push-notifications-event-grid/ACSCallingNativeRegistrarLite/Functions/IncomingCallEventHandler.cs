// Default URL for triggering event grid function in the local environment.
// http://localhost:7071/runtime/webhooks/EventGrid?functionName={functionname}
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using ACSCallingNativeRegistrarLite.Models;
using Newtonsoft.Json;
using ACSCallingNativeRegistrarLite.Utilities;
using System.Text;

namespace ACSCallingNativeRegistrarLite.Functions
{
    public class IncomingCallEventHandler
    {
        private readonly ILogger logger;

        public IncomingCallEventHandler(ILoggerFactory loggerFactory)
        {
            logger = loggerFactory.CreateLogger<IncomingCallEventHandler>();
        }

        [Function("IncomingCallEventHandler")]
        public async Task Run([EventGridTrigger] IncomingCallEventGridModel input)
        {
            // 1. Read all the required settings.
            var anhHubConnectionString = Environment.GetEnvironmentVariable("ANHHubConnectionString");
            var anhHubName = Environment.GetEnvironmentVariable("ANHHubName");
            var anhHubUrl = Environment.GetEnvironmentVariable("ANHHubUrl");
            var anhHubApiVersion = Environment.GetEnvironmentVariable("ANHHubApiVersion") ?? Defaults.ANH_DEFAULT_REST_API_VERSION;
            // NOTE: Here "direct" is very important, otherwise the push wont be delivered to the specified device.
            anhHubUrl += string.Format("?direct&api-version={0}", anhHubApiVersion);

            if (string.IsNullOrEmpty(anhHubConnectionString) || string.IsNullOrEmpty(anhHubName) || string.IsNullOrEmpty(anhHubUrl))
            {
                throw new Exception("One of the ANH hub settings not provided in settings");
            }

            // 2. Extract the mri from the inout data.
            logger.LogInformation("Recieved Event: " + JsonConvert.SerializeObject(input.Data?.to?.rawId));
            var incomingCallEventModel = input.Data ?? throw new Exception("Failed to get IncomingCallEventModel");
            var incomingCallUserMri = incomingCallEventModel?.to?.rawId;
            logger.LogInformation(string.Format("Got incoming call event for user: {0}, eventType: {1}", incomingCallUserMri, input.EventType));

            if (incomingCallUserMri == null)
            {
                throw new Exception("Mri of the incoming call recepient cannot be empty");
            }

            // 3. Get the registration info from the database.
            using var dbOps = new DbOps<ACSUserRegistrationInfo>(logger);
            var userRegistrationInfo = await Helpers.GetUserRegistrationInfo(dbOps, incomingCallUserMri);
            if (userRegistrationInfo == null || userRegistrationInfo.deviceInfos == null)
            {
                logger.LogWarning("No user registration info or no device tokens found");
                return;
            }

            // 4. Generate the SAS token for making the REST api to ANH.
            var authorization = Helpers.GenerateSasToken(anhHubConnectionString, anhHubName);

            // 5. Create the payload to sent to ANH.
            PushNotificationInfo? pushNotificationInfo = Helpers.ConvertToPNInfo(input, logger) ?? throw new Exception("Could not extract PN info");
            var body = new RootPayloadBody(pushNotificationInfo);

            // 6. Send the payload to all the devices registered.
            logger.LogInformation("CallId is: " + pushNotificationInfo.callId);
            foreach (var deviceInfo in userRegistrationInfo.deviceInfos)
            {
                using var client = new HttpClient();
                client.DefaultRequestHeaders.Add("Accept", "application/json");
                client.DefaultRequestHeaders.Add("Authorization", authorization);
                client.DefaultRequestHeaders.Add("ServiceBusNotification-Format", deviceInfo.platform);
                client.DefaultRequestHeaders.Add("ServiceBusNotification-Type", deviceInfo.platform);
                client.DefaultRequestHeaders.Add("ServiceBusNotification-DeviceHandle", deviceInfo.deviceToken);
                if (deviceInfo.platform.Equals(Platform.apple.ToString()))
                {
                    client.DefaultRequestHeaders.Add("ServiceBusNotification-Apns-Push-Type", "voip");
                }

                var payload = JsonConvert.SerializeObject(body);
                logger.LogDebug("Payload body => " + payload);
                using var httpContent = new StringContent(payload, Encoding.UTF8, "application/json");
                var httpResponse = await client.PostAsync(new Uri(anhHubUrl), httpContent).ConfigureAwait(false);
                if (httpResponse != null)
                {
                    if (httpResponse.IsSuccessStatusCode)
                    {
                        logger.LogInformation("Successfully sent ANH push");
                    }
                    else
                    {
                        logger.LogError(await httpResponse.Content.ReadAsStringAsync());
                        logger.LogCritical("Failed to send ANH push");
                    }
                }
                else
                {
                    logger.LogCritical("Got empty http response from ANH.");
                }
            }
        }
    }
}
