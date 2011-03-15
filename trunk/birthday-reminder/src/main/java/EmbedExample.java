import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import org.apache.log4j.Logger;

public class EmbedExample {

    private static final Logger LOGGER = Logger.getLogger(EmbedExample.class);

    public static void main(String... args) {
        try {
            Class.forName("org.hsqldb.jdbcDriver");
        } catch (Exception e) {
            System.out.println("ERROR: failed to load HSQLDB JDBC driver.");
            e.printStackTrace();
            return;
        }

        Connection c = null;
        try {
            c = DriverManager.getConnection("jdbc:hsqldb:file:../../data/bdays", "sa", "");
            if (c != null) {
                c.close();
                LOGGER.info("Embeded Test OK.");
            }
        } catch (SQLException e) {
            LOGGER.error("ERROR: failed to connect to server.", e);
            return;
        }

    }
}
