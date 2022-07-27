// Copyright (c) Microsoft. All rights reserved.

#import <Foundation/Foundation.h>

#ifdef Trouter_EXPORTS
    #define TROUTER_EXPORT OBJC_EXPORT
#else
    #define TROUTER_EXPORT
#endif


/**
 * Activity states that a user can be in on an endpoint
 */
typedef NS_ENUM(NSInteger, UserActivityState) {
    //! Initial state
    TrouterUserActivityStateUnknown       = 0,
    //! User is active according to the application
    TrouterUserActivityStateActive        = 1,
    //! User is not active according to the application
    TrouterUserActivityStateInactive      = 2
};

/**
 * Possible return values of TrouterResponse.send()
 */
typedef NS_ENUM(NSUInteger, TrouterSendResponseResult) {
    //! Response accepted, will be sent back to the service
    TrouterSendResponseResultOK           = 0,
    //! Too late, 504 (Timeout) has been already sent back
    TrouterSendResponseResultTimeout      = 1,
    //! send() was called multiple times on one Response
    TrouterSendResponseResultDuplicate    = 2,
    //! Mandatory parameters (status code) are not set
    TrouterSendResponseResultIncomplete   = 3,
    //! Trouter connection dropped, cannot reply now
    TrouterSendResponseResultDisconnected = 4
};

/**
 * Trouter HTTP-like request (service -> Trouter -> app)
 *
 * Represents one incoming request received by Trouter Client. Its content is
 * mostly a verbatim copy of what was sent by the originating service to
 * Trouter Service.
 */
TROUTER_EXPORT
@protocol TrouterRequest <NSObject>
    //! Request/response ID, useful for logging/debugging/tracing purposes
    @property(nonatomic, readonly)         long          id;
    //! HTTP method (GET, POST, ...)
    @property(nonatomic, readonly, strong) NSString*     method;
    //! HTTP path, including listener's prefix and any provided query parameters
    @property(nonatomic, readonly, strong) NSString*     path;
    //! HTTP headers
    @property(nonatomic, readonly, strong) NSDictionary* headers;
    //! HTTP body/content
    @property(nonatomic, readonly, strong) NSString*     body;
@end

/**
 * Trouter HTTP-like response (app -> Trouter -> service)
 *
 * Represents one outgoing response to be sent by Trouter Client. Always set
 * the status code, add any extra headers or body, then call `send()`.
 */
TROUTER_EXPORT
@protocol TrouterResponse <NSObject>
    //! Request/response ID, useful for logging/debugging/tracing purposes
    @property(nonatomic, readonly)         long          id;
    //! HTTP status code (200, 404, ...), mandatory
    @property(nonatomic, assign)           int           status;
    //! HTTP headers, optional
    @property(nonatomic, readonly, strong) NSDictionary* headers;
    //! HTTP body/content, optional
    @property(nonatomic, strong)           NSString*     body;

    /**
     * Send the response
     *
     * Trouter will add just a few of its own headers and otherwise forward the
     * response to the originating service that had sent the request.
     *
     * A successful return value `OK` means only that the response message has
     * been accepted and prepared for sending back. The actual transmission will
     * happen asynchronously later and might still fail for various reasons.
     *
     * @return TrouterSendResponseResultOK if successful, other code if not
     */
    -(TrouterSendResponseResult)send;
@end

/**
 * Information about the current Trouter connection
 *
 * Received in `Listener.onTrouterConnected()` every time the connection
 * parameters change.
 */
TROUTER_EXPORT
@protocol TrouterConnectionInfo <NSObject>
    //! Base URL used for routing messages from services to this client
    //! instance, i.e. not specific to a particular listener
    @property(nonatomic, readonly, strong) NSString* baseEndpointUrl;
    //! Tells if this `baseEndpointUrl` is different from the previous one and
    //! therefore if any dependent service registrations need to be updated to
    //! know where to send data
    @property(nonatomic, readonly)         BOOL      newEndpointUrl;
    //! Base URL prefix used for routing messages from clients to this client -
    //! replace the URL base (protocol + hostname) of `baseEndpointUrl` (or
    //! another per-listener endpoint URL) with this value to obtain the full
    //! client-to-client URL.
    @property(nonatomic, readonly, strong) NSString* c2cUrlBase;
    //! ID of this Trouter client, should stay the same between reconnects
    @property(nonatomic, readonly, strong) NSString* clientId;
    //! ID of the current Trouter connection, can change between reconnects
    @property(nonatomic, readonly, strong) NSString* connectionId;
    //! Expected lifetime of the current connection (ID) in seconds, as
    //! determined by Trouter Service
    @property(nonatomic, readonly)         int       connectionTtlSec;
@end

/**
 * Trouter listener
 *
 * Interface implemented by application to receive Trouter callbacks
 */
TROUTER_EXPORT
@protocol TrouterListener <NSObject>
    @required

    /**
     * Called when Trouter connection is (re-)established
     *
     * This is important mostly because of the `endpointUrl` as the URL where
     * messages are sent to by the originating service(s). Only after receiving
     * this callback and learning the Endpoint URL can the application register
     * the established channel for receiving messages.
     *
     * The Endpoint URL is intended for service-to-service communication, only
     * whitelisted authenticated services can access it and initiate Trouter
     * requests. Use `c2cUrlBase` from `connectionInfo` to obtain a similar URL
     * for client-to-client communication - see also `TrouterReplaceUrlBase()`.
     *
     * @note Called from an internal worker thread, listeners should offload any
     *       longer processing asynchronously.
     *
     * @param endpointUrl    A URL used for routing messages from services to
     *                       this listener
     * @param connectionInfo Additional Trouter connection information
     */
    -(void)onTrouterConnected:(NSString*)endpointUrl :(id<TrouterConnectionInfo>)connectionInfo;

    /**
     * Called when Trouter receives a request intended for this listener
     *
     * Application can inspect the contents of the incoming message by looking
     * at `request`, then fill in the outgoing `reponse` and send it back by
     * invoking its method `send()`.
     *
     * This can be done both synchronously when this method is called, or at a
     * later time asynchronously from any other context, if the application
     * stores the `response` object aside.
     *
     * In any case, a response ought to be sent to every received request. If
     * it is not, Trouter client will send a 504 (Timeout) message itself after
     * a configured time, but that will needlessly show up as an error on the
     * service side, even if you have processed the message successfully.
     *
     * For most simple applications, just sending a response with 200 (OK) right
     * away should be good enough.
     *
     * @param request  Incoming request object (read-only)
     * @param response Outgoing response object (to be filled in and sent)
     */
    -(void)onTrouterRequest:(id<TrouterRequest>)request :(id<TrouterResponse>)response;

    @optional

    /**
     * Called when Trouter connection drops
     *
     * No incoming requests can be received for now, no outgoing responses can
     * be sent either. Trouter client will reconnect as soon as possible.
     *
     * This state is most commonly caused by some temporary network issues
     * (switching from Wi-Fi to a wired network, bad signal etc.) or things
     * like a sleep/resume transition on the device.
     *
     * @note This method does not need to be implemented.
     */
    -(void)onTrouterDisconnected;

    /**
     * Called when the user activity state change (sent from this client) has been acknowledged by the server.
     *
     * @param correlationVector The correlation vector of the activity state change message that was sent by this client.
     * Note that this is the full outgoing vector, not just the base passed into ITrouter::SetUserActivityState.
     *
     * @note This method does not need to be implemented.
     */
    -(void)onTrouterUserActivityStateAccepted:(NSString*)correlationVector;

    /**
     * Called when some messages have been dropped on Trouter
     *
     * This can be called at any time by Trouter server. Clients can handle this
     * by manually fetching the latest messages, or in other appropriate way.
     * 
     * Note that this will be called only once per a group of flow tags, so it is
     * the client's responsibility to make sure the information doesn't get lost
     * and messages are synced when they should be. This means any retry logic,
     * crash recovery, or possibly storing the current sync state needs to be
     * handled by the client.
     *
     * Some of the examples of the message loss:
     * The message loss might occur when client queues got full and messages are rejected
     * The message to be delivered are already expired.
     *
     * @param flowTags Flow tags representing the type of messages being lost
     * 
     * @note This method does not need to be implemented.
     */
    -(void)onTrouterMessageLoss:(NSArray<NSString*>*)flowTags;
@end

/**
 * Trouter client
 *
 * Use to register and unregister your listeners. Calls are forwarded to the
 * underlying implementation, whatever that is on the current platform.
 *
 * The class does some wrapping inside and therefore unregisters all registered
 * listeners upon its destruction. Keep it alive (referenced) as long as your
 * listeners need to work (be notified).
 */
TROUTER_EXPORT
@protocol TrouterClient <NSObject>
    /**
     * Register a listener
     *
     * The specified listener will now be notified about any Trouter events. An
     * initial `onTrouterConnected()` callback will be received automatically
     * right away if Trouter is already connected, so that the listener can
     * learn the Endpoint URL etc.
     *
     * There can be only one listener registered for each `path`, but the path
     * can naturally comprise of multiple levels separated with a slash. The
     * listener with the longest, most specific matching path prefix for an
     * incoming message will be invoked to handle it.
     *
     * This method is very light-weight and can be called at any time.
     *
     * @param listener Listener object to register
     * @param path     HTTP-like relative path to register (e.g. '/foo')
     * @return `true` if successfully registered,
     *         `false` if there already is a registered listener for this exact
     *         path or if the given path is invalid
     */
    -(BOOL)registerListener:(id<TrouterListener>)listener forPath:(NSString*)path;

    /**
     * Unregister a listener
     *
     * The specified listener will not be notified about any Trouter events
     * anymore. `onTrouterDisconnected()` will not be called automatically
     * during unregistration.
     *
     * All registrations of this `Listener` object (i.e. possibly more than one,
     * registered with different paths) will be unregistered.
     *
     * This method is very light-weight and can be called at any time.
     *
     * @param listener Listener object to unregister
     * @return `true` if successfully unregistered,
     *         `false` if not registered in the first place
     */
    -(BOOL)unregisterListener:(id<TrouterListener>)listener;

    /**
     * Sets the user activity state on this endpoint/device
     *
     * The activity state will be sent to the service if it is different
     * from the previously sent state, upon reconnect, or under other
     * circumstances fully in the discretion of the client.
     *
     * The activity will be sent with a newly generated correlation vector on each call.
     */
    -(void)setUserActivityState:(UserActivityState)state;

    /**
     * Sets the user activity state on this endpoint/device
     *
     * The activity state will be sent to the service if it is different
     * from the previously sent state, upon reconnect, or under other
     * circumstances fully in the discretion of the client.
     *
     * The activity will be sent with a correlation vector extended from the one
     * passed into this function, and incremented as necessary.
     */
    -(void)setUserActivityState:(UserActivityState)state withBaseCorrelationVector:(NSString*)baseCorrelationVector;
@end

/**
 * Helper function to replace URL base (protocol + hostname)
 *
 * Useful when converting Trouter Endpoint URL to its client-to-client variant
 * with `TrouterConnectionInfo.c2cUrlBase`.
 */
TROUTER_EXPORT
NSString* TrouterReplaceUrlBase(NSString* existingUrl, NSString* newBase);
