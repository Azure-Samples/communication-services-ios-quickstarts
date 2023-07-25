using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;
using System.Text.Json.Serialization;

namespace ACSCallingNativeRegistrarLite.Models
{
    enum Platform
    {
        none,
        android,
        apple, 
        gcm, 
        windows,
        windowsphone, 
        adm,
        baidu
    }

    class DeviceInfo
    {
        [BsonElement("deviceUUID")]
        // Device uuid
        public required string deviceUUID { get; set; }

        [BsonElement("deviceToken")]
        // Device token
        public required string deviceToken { get; set; }

        [BsonElement("platform")]
        public required string platform { get; set; }
    }

    class ACSUserRegistrationInfo
    {
        [BsonId]
        [JsonIgnore]
        public required string _id { get; set; }

        [BsonIgnore]
        public required string acsMri
        {
            get
            {
                return _id;
            }

            set
            {
                _id = value;
            }
        }

        [BsonElement("deviceInfos")]
        public required List<DeviceInfo> deviceInfos { get; set;}
    }
}
