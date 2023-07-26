using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace ACSCallingNativeRegistrarLite.Models
{
    public class IncomingCallEventGridModel
    {
        public string? Id { get; set; }

        public string? Topic { get; set; }

        public string? Subject { get; set; }

        public string? EventType { get; set; }

        public DateTime? EventTime { get; set; }

        public IncomingCallEventModel? Data { get; set; }
    }

    public class IncomingCallEventModel
    {
        public To? to { get; set; }
        public From? from { get; set; }
        public string? serverCallId { get; set; }
        public string? callerDisplayName { get; set; }
        public string? incomingCallContext { get; set; }
        public string? correlationId { get; set; }
    }

    public class To
    {
        public string? kind { get; set; }
        public string? rawId { get; set; }
        public Communicationuser? communicationUser { get; set; }
    }

    public class Communicationuser
    {
        public string? id { get; set; }
    }

    public class From
    {
        public string? kind { get; set; }
        public string? rawId { get; set; }
        public Communicationuser? communicationUser { get; set; }
    }
}
