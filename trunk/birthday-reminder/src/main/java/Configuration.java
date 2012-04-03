/*
 * Config-Dir in environment.
 * Then load everything from dir.
 * Default dir is '.'
 */
import java.io.File;
import java.util.Properties;
import org.apache.log4j.Logger;

public class Configuration {
    private static final String CONFIG_FILE="bday.properties";
    private File configDir;
    private Properties properties;
    private static final Logger LOGGER = Logger.getLogger(Configuration.class);


    public Configuration() {
        final String value = System.getenv("BDAY_DIR");
        LOGGER.info("BDAY_DIR=" + value);
        
        properties = new Properties();
//        properties.put()
        
    }

    public File getConfigDir() {
        return this.configDir;
    }
}

