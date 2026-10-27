import config from '../vite.config.js';
// Exercise the real dev-proxy options against the isolated browser-test API.
export default {...config,server:{...config.server,host:'127.0.0.1',port:5111,strictPort:true,proxy:{'/api':{...config.server.proxy['/api'],target:'http://127.0.0.1:3111'}}}};
