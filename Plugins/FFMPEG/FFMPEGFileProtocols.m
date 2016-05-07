//
//  FFMPEGFileProtocols.m
//  FFMPEG
//
//  Created by Christopher Snowhill on 10/4/13.
//  Copyright 2013 __NoWork, Inc__. All rights reserved.
//

#include "Plugin.h"

#include <libavformat/avformat.h>
#include <libavformat/url.h> // INTERNAL
#include <libavutil/opt.h>

/* standard file protocol */

typedef struct FileContext {
    const AVClass *class;
    void *fd;
} FileContext;

static const AVOption file_options[] = {
    { NULL }
};

static const AVClass file_class = {
    .class_name = "file",
    .item_name  = av_default_item_name,
    .option     = file_options,
    .version    = LIBAVUTIL_VERSION_INT,
};

static const AVClass http_class = {
    .class_name = "http",
    .item_name  = av_default_item_name,
    .option     = file_options,
    .version    = LIBAVUTIL_VERSION_INT,
};

static const AVClass unpack_class = {
    .class_name = "unpack",
    .item_name  = av_default_item_name,
    .option     = file_options,
    .version    = LIBAVUTIL_VERSION_INT,
};

static int file_read(URLContext *h, unsigned char *buf, int size)
{
    FileContext *c = h->priv_data;
    NSObject* _fd = (__bridge NSObject *)(c->fd);
    id<CogSource> __unsafe_unretained fd = (id) _fd;
    return [fd read:buf amount:size];
}

static int file_check(URLContext *h, int mask)
{
    return mask & AVIO_FLAG_READ;
}

static int file_open(URLContext *h, const char *filename, int flags)
{
    FileContext *c = h->priv_data;
    id<CogSource> fd;
    
    if (flags & AVIO_FLAG_WRITE) {
        return -1;
    }
    
    NSString * urlString = [NSString stringWithUTF8String:filename];
    NSURL * url = [NSURL URLWithString:[urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    
    id audioSourceClass = NSClassFromString(@"AudioSource");
    fd = [audioSourceClass audioSourceForURL:url];
    
    if (![fd open:url])
        return -1;
    
    c->fd = (void*)CFBridgingRetain(fd);
    
    return 0;
}

static int http_open(URLContext *h, const char *filename, int flags)
{
    int rval = file_open( h, filename, flags );
    h->is_streamed = 1;
    return rval;
}

/* XXX: use llseek */
static int64_t file_seek(URLContext *h, int64_t pos, int whence)
{
    FileContext *c = h->priv_data;
    NSObject* _fd = (__bridge NSObject *)(c->fd);
    id<CogSource> __unsafe_unretained fd = (id) _fd;
    return [fd seek:pos whence:whence] ? [fd tell] : -1;
}

static int64_t http_seek(URLContext *h, int64_t pos, int whence)
{
    return -1;
}

static int file_close(URLContext *h)
{
    FileContext *c = h->priv_data;
    CFBridgingRelease(c->fd);
    return 0;
}

static URLProtocol ff_file_protocol = {
    .name                = "file",
    .url_open            = file_open,
    .url_read            = file_read,
    .url_seek            = file_seek,
    .url_close           = file_close,
    .url_check           = file_check,
    .priv_data_size      = sizeof(FileContext),
    .priv_data_class     = &file_class,
};

static URLProtocol ff_http_protocol = {
    .name                = "http",
    .url_open            = http_open,
    .url_read            = file_read,
    .url_seek            = http_seek,
    .url_close           = file_close,
    .url_check           = file_check,
    .priv_data_size      = sizeof(FileContext),
    .flags               = URL_PROTOCOL_FLAG_NETWORK,
    .priv_data_class     = &http_class,
};

static URLProtocol ff_unpack_protocol = {
    .name                = "unpack",
    .url_open            = file_open,
    .url_read            = file_read,
    .url_seek            = file_seek,
    .url_close           = file_close,
    .url_check           = file_check,
    .priv_data_size      = sizeof(FileContext),
    .priv_data_class     = &unpack_class,
};

void registerCogProtocols()
{
    ffurl_register_protocol(&ff_file_protocol);
    ffurl_register_protocol(&ff_http_protocol);
    ffurl_register_protocol(&ff_unpack_protocol);
}
