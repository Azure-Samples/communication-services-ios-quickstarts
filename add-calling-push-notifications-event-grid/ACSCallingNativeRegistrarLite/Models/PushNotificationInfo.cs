using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace ACSCallingNativeRegistrarLite.Models
{
    internal class PushNotificationInfo
    {
        public PushNotificationInfo(int eventId, string cp) 
        {
            this.eventId = eventId;
            this.cp = cp;
        }

        public int eventId { get; }
        public string cp { get; }

        public string? callId { get; set; }
        public string? recipientId { get; set; }
        public string? callerId { get; set; }
        public string? displayName { get; set; }
        public string? videoCall { get; set; }
    }

    // This is required otherwise ANH rejects the payload in the REST api.
    internal class Aps
    {
        
    }

    internal class RootPayloadBody
    {
        public RootPayloadBody(PushNotificationInfo data)
        { 
            this.aps = new Aps();
            this.data = data;
        }

        public Aps aps { get; }

        public PushNotificationInfo data { get; }
    }
}
