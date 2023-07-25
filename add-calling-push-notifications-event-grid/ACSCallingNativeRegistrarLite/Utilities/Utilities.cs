using Microsoft.Azure.Functions.Worker.Http;
using Newtonsoft.Json;
using MongoDB.Bson;
using System.Text;
using System.Net;
using ACSCallingNativeRegistrarLite.Models;
using MongoDB.Driver;
using System.Security.Cryptography;
using Microsoft.Extensions.Logging;

namespace ACSCallingNativeRegistrarLite.Utilities
{
    internal static class Helpers
    {
        public static HttpResponseData CreateResponseData(HttpRequestData req, HttpStatusCode status, string message)
        {
            var response = req.CreateResponse(status);
            response.Headers.Add("Content-Type", "text/json; charset=utf-8");
            response.WriteString(message);
            return response;
        }

        public static async Task<ACSUserRegistrationInfo?> GetUserRegistrationInfo(DbOps<ACSUserRegistrationInfo> dbOps, string mri)
        {
            FilterDefinition<ACSUserRegistrationInfo> filter = new BsonDocument("_id", mri);
            // First fetch the entry if it exists
            var acsUserRegistrationInfos = await dbOps.FindAsync(filter)!.ConfigureAwait(false);
            if (acsUserRegistrationInfos.Count == 1)
            {
                var acsUserRegistrationInfo = acsUserRegistrationInfos.FirstOrDefault();
                return acsUserRegistrationInfo;
            }
            else
            {
                return null;
            }
        }

        public static string GenerateSasToken(string connectionString, string hubName)
        {
            var parts = connectionString.Split(';');
            if (parts.Length != 3)
            {
               throw new Exception("Invalid connections string provided");
            }

            string endpoint = "";
            string sasKeyName = "";
            string sasKeyValue = "";

            foreach (var part in parts)
            {
               if (part.StartsWith("Endpoint"))
               {
                   endpoint = "https" + part.Substring(11);
               }

               if (part.StartsWith("SharedAccessKeyName"))
               {
                   sasKeyName = part.Substring(20);
               }

               if (part.StartsWith("SharedAccessKey"))
               {
                   sasKeyValue = part.Substring(16);
               }
            }

            var targetUri = endpoint + hubName;
            var myUri = WebUtility.UrlEncode(targetUri).ToLower();
            var expiry = ((int)(DateTime.UtcNow.Subtract(new DateTime(1970, 1, 1))).TotalSeconds + 300).ToString();
            var toSign = myUri + "\n" + expiry;
            var signature = WebUtility.UrlEncode(SignString(toSign, sasKeyValue));
            var authFormat = "SharedAccessSignature sig={0}&se={1}&skn={2}&sr={3}";
            var sasToken = string.Format(authFormat, signature, expiry, sasKeyName, myUri);
            return sasToken;
        }

        public static PushNotificationInfo? ConvertToPNInfo(IncomingCallEventGridModel eventGridModel, ILogger log)
        {
            if (eventGridModel.Data == null)
            {
                log.LogCritical("Content provided is null");
                return null;
            }

            if (eventGridModel.EventType == null)
            {
                log.LogCritical("Event type provided is null");
                return null;
            }

            int eventId = 0;
            if (eventGridModel.EventType.Equals("Microsoft.Communication.IncomingCall"))
            {
                eventId = 107;
            }

            if (eventId == 0)
            {
                log.LogError("Could not determine event type");
                return null;
            }

            var incomingCallEventModel = eventGridModel.Data;
            if (incomingCallEventModel == null)
            {
                log.LogError("IncomingCallEventModel is null");
                return null;
            }

            string? cp = ExtractCC(incomingCallEventModel.incomingCallContext, log);

            if (cp == null)
            {
                log.LogError("Could not extract cp");
                return null;
            }

            // Validate to and from is not null
            if (incomingCallEventModel.to == null || incomingCallEventModel.from == null)
            {
                log.LogError("To or From information from payload could not be extracted.");
                return null;
            }

            PushNotificationInfo pushNotification = new PushNotificationInfo(eventId, cp)
            {
                callId = incomingCallEventModel.correlationId,
                // TODO: Cannot determine this as of now
                videoCall = "false",
                recipientId = incomingCallEventModel.to.rawId,
                callerId = incomingCallEventModel.from.rawId,
                displayName = incomingCallEventModel.callerDisplayName,
            };

            return pushNotification;
        }

        private static byte[] DecodeBase64(string input)
        {
            byte[] base64EncodedBytes = Encoding.UTF8.GetBytes(input);
            byte[] decodedBytes = new byte[base64EncodedBytes.Length];
            FromBase64Transform myTransform = new FromBase64Transform();
            _ = myTransform.TransformBlock(base64EncodedBytes, 0, base64EncodedBytes.Length, decodedBytes, 0);
            return decodedBytes;
        }

        private static string GetSubstring(string input, string startString, string endString)
        {
            int pFrom = input.IndexOf(startString) + startString.Length;
            int pTo = input.LastIndexOf(endString);
            return input.Substring(pFrom, pTo - pFrom);
        }

        private static string? ExtractCC(string? incomingCallContext, ILogger logger)
        {
            if (incomingCallContext == null)
            {
                logger.LogCritical("IncomingCallContext in the payload is empty");
                return null;
            }
            var parts = incomingCallContext.Split('.');
            byte[] data = DecodeBase64(parts[1]);
            string decodedString = Encoding.UTF8.GetString(data);
            var cc = GetSubstring(decodedString, "\"cc\":\"", ",\"shrToken\"");
            logger.LogInformation("CC => " + cc);
            return cc;
        }

        private static string SignString(string toSign, string sasKeyValue)
        {
            var key = Encoding.UTF8.GetBytes(sasKeyValue);
            var toSignBytes = Encoding.UTF8.GetBytes(toSign);
            using (var hmac = new HMACSHA256(key))
            {
                var hash = hmac.ComputeHash(toSignBytes);
                return Convert.ToBase64String(hash);
            }
        }
    }

    internal class RequestBodyParser<T>
    {
        public async Task<T?> Read(HttpRequestData req)
        {
            if (req == null)
            {
                throw new ArgumentNullException(nameof(req));
            }

            string requestBody;
            using (var streamReader = new StreamReader(req.Body))
            {
                requestBody = await streamReader.ReadToEndAsync().ConfigureAwait(false);
            }

            if (string.IsNullOrEmpty(requestBody))
            {
                throw new Exception("Body is empty");
            }

            T? deserializedObj;
            try
            {
                var jsonSerializerSettings = new JsonSerializerSettings();
                deserializedObj = JsonConvert.DeserializeObject<T>(requestBody, jsonSerializerSettings);
            }
            catch (JsonSerializationException)
            {
                throw new Exception(string.Format("Failed to deserialize body for {0}", nameof(T)));
            }

            return deserializedObj;
        }
    }
}
